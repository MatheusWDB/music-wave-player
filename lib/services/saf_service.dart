import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resultado de pedir acesso à pasta raiz da biblioteca.
enum SafAccessResult { granted, cancelled, wrongFolder }

/// Gerencia o acesso SAF (Storage Access Framework) à pasta de músicas.
///
/// O Android 10+ exige que o usuário conceda acesso explícito a pastas
/// externas para que o app possa escrever arquivos. Este serviço:
///   1. Verifica se já temos um URI persistente salvo.
///   2. Se não, dispara o seletor de pasta nativo.
///   3. Salva o URI concedido em SharedPreferences para uso futuro.
class SafService {
  static const _kSafUriKey = 'saf_music_folder_uri';

  static const _channel = MethodChannel('br.com.hematsu.music_wave_player/saf');

  /// Retorna o URI SAF persistente já salvo, ou null se ainda não concedido.
  static Future<String?> getSavedUri() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSafUriKey);
  }

  /// Solicita ao usuário que selecione a pasta de músicas via seletor nativo.
  /// Retorna o URI concedido ou null se o usuário cancelar.
  static Future<String?> requestFolderAccess() async {
    try {
      final String? uri = await _channel.invokeMethod('openFolderPicker');
      if (uri != null && uri.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kSafUriKey, uri);
        return uri;
      }
    } on PlatformException catch (e) {
      debugPrint('SafService.requestFolderAccess erro: $e');
    }
    return null;
  }

  /// Pede acesso à pasta raiz da biblioteca e só salva o URI se o usuário
  /// escolheu exatamente [rootPath]; qualquer outra pasta é recusada para não
  /// gravar arquivos fora do que o indexador enxerga.
  static Future<SafAccessResult> requestRootAccess(String rootPath) async {
    try {
      final String? uri = await _channel.invokeMethod('openFolderPicker');
      if (uri == null || uri.isEmpty) return SafAccessResult.cancelled;

      final picked = pathFromTreeUri(uri);
      if (picked == null || _trimSlash(picked) != _trimSlash(rootPath)) {
        return SafAccessResult.wrongFolder;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSafUriKey, uri);
      return SafAccessResult.granted;
    } on PlatformException catch (e) {
      debugPrint('SafService.requestRootAccess erro: $e');
      return SafAccessResult.cancelled;
    }
  }

  /// Converte um URI de árvore do SAF no caminho real do armazenamento.
  /// Ex: content://.../tree/primary%3AMusic -> /storage/emulated/0/Music
  static String? pathFromTreeUri(String uriString) {
    final segments = Uri.parse(uriString).pathSegments;
    final treeIndex = segments.indexOf('tree');
    if (treeIndex < 0 || treeIndex + 1 >= segments.length) return null;

    final documentId = segments[treeIndex + 1]; // ex: primary:Music
    final colon = documentId.indexOf(':');
    if (colon < 0) return null;

    final volume = documentId.substring(0, colon);
    final relative = documentId.substring(colon + 1);
    final base = volume == 'primary'
        ? '/storage/emulated/0'
        : '/storage/$volume';
    return relative.isEmpty ? base : '$base/$relative';
  }

  static String _trimSlash(String path) =>
      path.endsWith('/') ? path.substring(0, path.length - 1) : path;

  /// Garante que temos acesso SAF válido.
  /// Se já temos um URI salvo, retorna ele diretamente.
  /// Caso contrário, abre o seletor.
  static Future<String?> ensureAccess() async {
    final saved = await getSavedUri();
    if (saved != null) return saved;
    return requestFolderAccess();
  }

  /// Copia um arquivo temporário (srcPath) para substituir o arquivo original
  /// identificado pelo URI SAF da pasta + nome do arquivo.
  ///
  /// O ffmpeg já escreveu no arquivo temporário; agora precisamos mover
  /// o resultado de volta para a pasta protegida pelo SAF.
  static Future<bool> copyTempToSaf({
    required String tempPath,
    required String targetFileName,
    required String folderUri,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('copyTempToSaf', {
        'tempPath': tempPath,
        'targetFileName': targetFileName,
        'folderUri': folderUri,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('SafService.copyTempToSaf erro: $e');
      return false;
    }
  }

  static void debugPrint(String msg) {
    // ignore: avoid_print
    if (Platform.environment.containsKey('FLUTTER_TEST') == false) {
      // ignore: avoid_print
      print(msg);
    }
  }
}
