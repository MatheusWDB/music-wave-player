import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// DIAGNÓSTICO TEMPORÁRIO — escrita do arquivo de log de diagnóstico.
/// Remover junto com o resto do diagnóstico. Escreve em armazenamento
/// externo específico do app (sem permissão extra); puxa com:
///   adb pull /storage/emulated/0/Android/data/br.com.hematsu.music_wave_player/files/loudness_log.txt
class DiagLog {
  DiagLog._();

  // Escritas encadeadas: appends concorrentes embaralhavam linhas no arquivo.
  static Future<void> _chain = Future<void>.value();
  static File? _file;

  /// Grava [line] com o timestamp do momento da chamada (não da escrita).
  static Future<void> write(String line) {
    final stamped = '${DateTime.now().toIso8601String()}  $line\n';
    _chain = _chain.then((_) async {
      try {
        if (_file == null) {
          final dir = await getExternalStorageDirectory();
          if (dir == null) return;
          _file = File('${dir.path}/loudness_log.txt');
        }
        await _file!.writeAsString(stamped, mode: FileMode.append);
      } catch (_) {
        // Log é só diagnóstico — nunca deve derrubar o app.
      }
    });
    return _chain;
  }

  /// Linha com a tag [Player] (também vai pro console de debug).
  static void player(String message) {
    debugPrint('[Player] $message');
    unawaited(write('[Player] $message'));
  }

  /// Erro não tratado: mensagem, exceção e as primeiras linhas da stack,
  /// tudo em uma linha só.
  static void error(String message, Object? err, StackTrace? stack) {
    final frames = (stack?.toString() ?? '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(8)
        .join(' | ');
    player('ERRO — $message: $err | $frames');
  }
}
