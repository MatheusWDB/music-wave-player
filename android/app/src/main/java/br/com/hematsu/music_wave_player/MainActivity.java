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

import com.ryanheise.audioservice.AudioServiceActivity;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends AudioServiceActivity {

    private static final String SAF_CHANNEL = "br.com.hematsu.music_wave_player/saf";
    private static final int REQUEST_OPEN_FOLDER = 1001;

    private MethodChannel.Result pendingResult = null;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            SAF_CHANNEL
        ).setMethodCallHandler((call, result) -> {

            if (call.method.equals("openFolderPicker")) {
                pendingResult = result;
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
                intent.putExtra(
                    DocumentsContract.EXTRA_INITIAL_URI,
                    Uri.parse("content://com.android.externalstorage.documents/tree/primary%3AMusic")
                );
                intent.addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION |
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION |
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION |
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                );
                startActivityForResult(intent, REQUEST_OPEN_FOLDER);

            } else if (call.method.equals("copyTempToSaf")) {
                String tempPath = call.argument("tempPath");
                String targetFileName = call.argument("targetFileName");
                String folderUriString = call.argument("folderUri");

                if (tempPath == null || targetFileName == null || folderUriString == null) {
                    result.error("INVALID_ARGS", "Argumentos inválidos", null);
                    return;
                }

                try {
                    Uri folderUri = Uri.parse(folderUriString);
                    DocumentFile folderDoc = DocumentFile.fromTreeUri(getApplicationContext(), folderUri);

                    if (folderDoc == null) {
                        result.error("FOLDER_NOT_FOUND", "Pasta não encontrada", null);
                        return;
                    }

                    DocumentFile targetDoc = folderDoc.findFile(targetFileName);
                    if (targetDoc == null) {
                        String mimeType = "audio/*";
                        if (targetFileName.endsWith(".m4a")) mimeType = "audio/mp4";
                        else if (targetFileName.endsWith(".mp3")) mimeType = "audio/mpeg";
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

            } else if (call.method.equals("scanMedia")) {
                String path = call.argument("path");
                if (path == null) {
                    result.error("INVALID_ARGS", "Path nulo", null);
                    return;
                }

                MediaScannerConnection.scanFile(
                    getApplicationContext(),
                    new String[]{ path },
                    null,
                    (scannedPath, uri) -> result.success(true)
                );

            } else {
                result.notImplemented();
            }
        });
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode == REQUEST_OPEN_FOLDER) {
            MethodChannel.Result result = pendingResult;
            pendingResult = null;
            if (result == null) return;

            if (resultCode == Activity.RESULT_OK && data != null) {
                Uri uri = data.getData();
                if (uri == null) { result.success(null); return; }

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