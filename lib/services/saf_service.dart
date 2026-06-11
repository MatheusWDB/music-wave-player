import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
