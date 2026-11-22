package br.com.hematsu.music_wave_player;

import android.app.Activity;
import android.content.Intent;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.provider.DocumentsContract;

import androidx.documentfile.provider.DocumentFile;

import java.io.File;
import java.io.FileInputStream;
import java.io.OutputStream;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String SAF_CHANNEL = "br.com.hematsu.music_wave_player/saf";
    private static final int REQUEST_OPEN_FOLDER = 1001;

    private MethodChannel.Result pendingResult = null;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                SAF_CHANNEL).setMethodCallHandler((call, result) -> {

                    if (call.method.equals("openFolderPicker")) {
                        pendingResult = result;
                        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
                        intent.putExtra(
                                DocumentsContract.EXTRA_INITIAL_URI,
                                Uri.parse("content://com.android.externalstorage.documents/tree/primary%3AMusic"));
                        intent.addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION |
                                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION |
                                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION |
                                        Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);
                        startActivityForResult(intent, REQUEST_OPEN_FOLDER);

                    } else if (call.method.equals("copyTempToSaf")) {
                        String tempPath = call.argument("tempPath");
                        String targetFileName = call.argument("targetFileName");
                        String folderUriString = call.argument("folderUri");
                        String relativeDir = call.argument("relativeDir");

                        if (tempPath == null || targetFileName == null || folderUriString == null) {
                            result.error("INVALID_ARGS", "Argumentos inválidos", null);
                            return;
                        }

                        try {
                            Uri folderUri = Uri.parse(folderUriString);
                            DocumentFile folderDoc = resolveFolder(
                                    DocumentFile.fromTreeUri(getApplicationContext(), folderUri),
                                    relativeDir);

                            if (folderDoc == null) {
                                result.error("FOLDER_NOT_FOUND", "Pasta não encontrada", null);
                                return;
                            }

                            DocumentFile targetDoc = folderDoc.findFile(targetFileName);
                            if (targetDoc == null) {
                                String mimeType = "audio/*";
                                if (targetFileName.endsWith(".m4a"))
                                    mimeType = "audio/mp4";
                                else if (targetFileName.endsWith(".mp3"))
                                    mimeType = "audio/mpeg";
                                targetDoc = folderDoc.createFile(mimeType, targetFileName);
                                if (targetDoc == null) {
                                    result.error("CREATE_FAILED", "Não foi possível criar: " + targetFileName, null);
                                    return;
                                }
                            }

                            File tempFile = new File(tempPath);
                            OutputStream outputStream = getContentResolver().openOutputStream(targetDoc.getUri(), "wt");
                            if (outputStream == null) {
                                result.error("STREAM_FAILED", "Não foi possível abrir stream de escrita", null);
                                return;
                            }

                            FileInputStream inputStream = new FileInputStream(tempFile);
                            byte[] buffer = new byte[8192];
                            int bytesRead;
                            while ((bytesRead = inputStream.read(buffer)) != -1) {
                                outputStream.write(buffer, 0, bytesRead);
                            }
                            inputStream.close();
                            outputStream.close();

                            result.success(true);

                        } catch (Exception e) {
                            result.error("COPY_FAILED", e.getMessage(), null);
                        }

                    } else if (call.method.equals("renameFile")) {
                        String folderUriString = call.argument("folderUri");
                        String relativeDir = call.argument("relativeDir");
                        String oldFileName = call.argument("oldFileName");
                        String newFileName = call.argument("newFileName");

                        if (folderUriString == null || oldFileName == null || newFileName == null) {
                            result.error("INVALID_ARGS", "Argumentos inválidos", null);
                            return;
                        }

                        try {
                            Uri treeUri = Uri.parse(folderUriString);

                            // Caminho direto: monta o URI do documento a partir do id da árvore
                            // (evita listar a pasta inteira a cada arquivo renomeado).
                            Uri renamedUri = null;
                            try {
                                String docId = DocumentsContract.getTreeDocumentId(treeUri)
                                        + (relativeDir == null || relativeDir.isEmpty() ? "" : "/" + relativeDir)
                                        + "/" + oldFileName;
                                Uri docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId);
                                renamedUri = DocumentsContract.renameDocument(
                                        getContentResolver(), docUri, newFileName);
                            } catch (Exception ignored) {
                                // Cai para a busca por nome abaixo.
                            }

                            if (renamedUri != null) {
                                DocumentFile renamed = DocumentFile.fromSingleUri(getApplicationContext(), renamedUri);
                                String finalName = renamed != null ? renamed.getName() : null;
                                result.success(finalName != null ? finalName : newFileName);
                                return;
                            }

                            DocumentFile folderDoc = resolveFolder(
                                    DocumentFile.fromTreeUri(getApplicationContext(), treeUri),
                                    relativeDir);
                            DocumentFile fileDoc = folderDoc == null ? null : folderDoc.findFile(oldFileName);
                            if (fileDoc == null) {
                                result.error("FILE_NOT_FOUND", "Arquivo não encontrado: " + oldFileName, null);
                                return;
                            }
                            if (!fileDoc.renameTo(newFileName)) {
                                result.error("RENAME_FAILED", "Não foi possível renomear: " + oldFileName, null);
                                return;
                            }
                            result.success(fileDoc.getName());

                        } catch (Exception e) {
                            result.error("RENAME_FAILED", e.getMessage(), null);
                        }

                    } else if (call.method.equals("scanMedia")) {
                        String path = call.argument("path");
                        if (path == null) {
                            result.error("INVALID_ARGS", "Path nulo", null);
                            return;
                        }

                        MediaScannerConnection.scanFile(
                                getApplicationContext(),
                                new String[] { path },
                                null,
                                (scannedPath, uri) -> result.success(true));

                    } else {
                        result.notImplemented();
                    }
                });
    }

    /**
     * Desce da pasta raiz concedida até a subpasta indicada (ex.: "Rock/Album").
     * Vazio ou nulo devolve a própria raiz; retorna null se algum trecho do
     * caminho não existir.
     */
    private DocumentFile resolveFolder(DocumentFile root, String relativeDir) {
        if (root == null || relativeDir == null || relativeDir.isEmpty()) {
            return root;
        }
        DocumentFile current = root;
        for (String segment : relativeDir.split("/")) {
            if (segment.isEmpty()) {
                continue;
            }
            current = current.findFile(segment);
            if (current == null || !current.isDirectory()) {
                return null;
            }
        }
        return current;
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode == REQUEST_OPEN_FOLDER) {
            MethodChannel.Result result = pendingResult;
            pendingResult = null;
            if (result == null)
                return;

            if (resultCode == Activity.RESULT_OK && data != null) {
                Uri uri = data.getData();
                if (uri == null) {
                    result.success(null);
                    return;
                }

                int takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION |
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION;
                getContentResolver().takePersistableUriPermission(uri, takeFlags);
                result.success(uri.toString());
            } else {
                result.success(null);
            }
        }
    }
}
