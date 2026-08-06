import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:music_wave_player/main.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/services/backup_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _sharing = false;
  bool _savingToFolder = false;
  bool _pickingImportFile = false;

  String _generateBaseFileName() {
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return 'musicwave_backup_$stamp';
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _shareBackup() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final config = context.read<Configuration>();
      final content = await BackupService.buildBackup(config);

      final dir = await getTemporaryDirectory();
      final fileName = '${_generateBaseFileName()}.mwp';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Backup do MusicWave Player',
        ),
      );
    } catch (e) {
      _showSnack('Erro ao gerar backup: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _saveToFolder() async {
    if (_savingToFolder) return;
    setState(() => _savingToFolder = true);
    try {
      final config = context.read<Configuration>();
      final content = await BackupService.buildBackup(config);
      final bytes = Uint8List.fromList(utf8.encode(content));

      final savedPath = await FileSaver.instance.saveAs(
        name: _generateBaseFileName(),
        bytes: bytes,
        fileExtension: 'mwp',
        mimeType: MimeType.other,
      );

      if (savedPath != null && savedPath.isNotEmpty) {
        _showSnack('Backup salvo com sucesso.');
      }
    } catch (e) {
      _showSnack('Erro ao salvar backup: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingToFolder = false);
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _importBackup() async {
    if (_pickingImportFile) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mwp'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _pickingImportFile = true);
    try {
      final content = await File(path).readAsString(encoding: utf8);
      final parsed = BackupService.parseBackup(content);

      switch (parsed) {
        case BackupParseFailure(:final reason):
          _showSnack(reason, isError: true);
        case BackupParseSuccess(:final data):
          if (!mounted) return;
          final confirmed = await _confirmImport(data);
          if (confirmed != true) return;
          // Não aguarda — a restauração roda desacoplada da tela, com
          // feedback via SnackBar global mesmo que o usuário navegue para
          // outra tela antes de terminar.
          _startRestore(data);
      }
    } catch (e) {
      _showSnack('Erro ao ler o arquivo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _pickingImportFile = false);
    }
  }

  Future<void> _startRestore(BackupData data) async {
    final config = context.read<Configuration>();
    AppMessenger.show('Restaurando backup em segundo plano...');

    final summary = await BackupService.restore(data: data, config: config);

    AppMessenger.show(
      'Restauração concluída: ${summary.playlistsRestored} playlist${summary.playlistsRestored == 1 ? '' : 's'}, '
      '${summary.tracksRecreated} faixa${summary.tracksRecreated == 1 ? '' : 's'} recriada${summary.tracksRecreated == 1 ? '' : 's'}, '
      '${summary.sessionsRestored} ${summary.sessionsRestored == 1 ? 'sessão' : 'sessões'}.',
    );

    if (mounted) {
      await _showSummary(summary);
    }
  }

  Future<bool?> _confirmImport(BackupData data) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: Text(
          'Este backup contém ${data.playlists.length} playlist${data.playlists.length == 1 ? '' : 's'}, '
          '${data.trackMeta.length} música${data.trackMeta.length == 1 ? '' : 's'} com nota/oculta e '
          '${data.playSessions.length} ${data.playSessions.length == 1 ? 'sessão' : 'sessões'} de reprodução.\n\n'
          'Faixas que sumiram da biblioteca serão recriadas automaticamente, se o arquivo ainda existir no mesmo local. '
          'Os dados são mesclados com os já existentes. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSummary(RestoreSummary summary) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restauração concluída'),
        content: Text(
          '${summary.playlistsRestored} playlist${summary.playlistsRestored == 1 ? '' : 's'} restaurada${summary.playlistsRestored == 1 ? '' : 's'}.\n'
          '${summary.tracksRecreated} faixa${summary.tracksRecreated == 1 ? '' : 's'} recriada${summary.tracksRecreated == 1 ? '' : 's'} a partir do backup.\n'
          '${summary.trackMetaMatched} música${summary.trackMetaMatched == 1 ? '' : 's'} com nota/oculta aplicada'
          '${summary.trackMetaMatched == 1 ? '' : 's'}'
          '${summary.trackMetaUnmatched > 0 ? ' (${summary.trackMetaUnmatched} não encontrada${summary.trackMetaUnmatched == 1 ? '' : 's'})' : ''}.\n'
          '${summary.sessionsRestored} ${summary.sessionsRestored == 1 ? 'sessão' : 'sessões'} de reprodução restaurada'
          '${summary.sessionsRestored == 1 ? '' : 's'}'
          '${summary.sessionsUnmatched > 0 ? ' (${summary.sessionsUnmatched} não encontrada${summary.sessionsUnmatched == 1 ? '' : 's'})' : ''}.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup e Restauração')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'EXPORTAR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Inclui playlists, notas, músicas ocultas, histórico de reprodução e configurações (equalizador, ordenação, crossfade).',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharing ? null : _shareBackup,
                    icon: _sharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share_outlined),
                    label: const Text('Compartilhar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _savingToFolder ? null : _saveToFolder,
                    icon: _savingToFolder
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.folder_outlined),
                    label: const Text('Salvar em pasta'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(height: 1),
            const SizedBox(height: 24),
            Text(
              'RESTAURAR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Selecione um arquivo .mwp. A restauração roda em segundo plano — você pode navegar para outra tela enquanto isso.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _pickingImportFile ? null : _importBackup,
              icon: _pickingImportFile
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_open_outlined),
              label: const Text('Selecionar arquivo (.mwp)'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
