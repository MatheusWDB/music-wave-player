import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/audio_transitions_bottom_sheet.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/services/indexing_service.dart';
import 'package:music_wave_player/screens/backup_restore_screen.dart';
import 'package:music_wave_player/screens/download_screen.dart';
import 'package:music_wave_player/screens/equalizer_screen.dart';
import 'package:music_wave_player/screens/hidden_tracks_screen.dart';
import 'package:music_wave_player/screens/most_played_screen.dart';
import 'package:music_wave_player/screens/recently_added_screen.dart';
import 'package:music_wave_player/screens/root_directory_config_screen.dart';
import 'package:music_wave_player/screens/statistics_screen.dart';

/// Bottom sheet de menu com atalhos para as telas secundárias do app
/// (biblioteca, músicas ocultas, transições, estatísticas, backup, etc.).
class AppMenuSheet extends ConsumerWidget {
  const AppMenuSheet({super.key});

  void _go(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmRescanLoudness(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Capturados antes de fechar o menu: depois do pop, o context e o ref
    // do sheet deixam de ser válidos.
    final notifier = ref.read(indexingNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recalcular volume'),
        content: const Text(
          'Reescaneia o volume de todas as músicas para corrigir diferenças '
          'entre faixas. Leva alguns minutos e roda em segundo plano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Recalcular'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (context.mounted) Navigator.pop(context);
    final result = await notifier.rescanLoudness();
    messenger.showSnackBar(SnackBar(content: Text(_rescanSummary(result))));
  }

  String _rescanSummary(LoudnessRescanResult? result) {
    if (result == null) {
      return 'Não foi possível recalcular agora. Aguarde a operação em andamento.';
    }
    final failed = result.failed > 0 ? ', ${result.failed} sem consenso' : '';
    return 'Volume recalculado: ${result.corrected} corrigidas, '
        '${result.unchanged} já corretas$failed.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy = ref.watch(
      indexingNotifierProvider.select((s) => s.valueOrNull?.isBusy ?? false),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.library_music_outlined,
                color: colorScheme.primary,
              ),
              title: const Text('Biblioteca'),
              subtitle: const Text('Configurar pasta e reindexar'),
              onTap: () => _go(context, const RootDirectoryConfigScreen()),
            ),
            ListTile(
              leading: Icon(
                Icons.download_outlined,
                color: colorScheme.primary,
              ),
              title: const Text('Baixar músicas'),
              subtitle: const Text('Baixar áudio de um link do YouTube'),
              onTap: () => _go(context, const DownloadScreen()),
            ),
            ListTile(
              leading: Icon(
                Icons.visibility_off_outlined,
                color: colorScheme.primary,
              ),
              title: const Text('Músicas ocultas'),
              subtitle: const Text('Ver e reexibir músicas ocultadas'),
              onTap: () => _go(context, const HiddenTracksScreen()),
            ),
            ListTile(
              leading: Icon(Icons.swap_horiz, color: colorScheme.primary),
              title: const Text('Transições de áudio'),
              subtitle: const Text('Crossfade e fade ao pausar'),
              onTap: () {
                Navigator.pop(context);
                AudioTransitionsBottomSheet.show(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.graphic_eq, color: colorScheme.primary),
              title: const Text('Equalizador'),
              subtitle: const Text('Ajustar graves, médios e agudos'),
              onTap: () => _go(context, const EqualizerScreen()),
            ),
            ListTile(
              enabled: !isBusy,
              leading: Icon(
                Icons.volume_up_outlined,
                color: colorScheme.primary,
              ),
              title: const Text('Recalcular volume'),
              subtitle: Text(
                isBusy
                    ? 'Aguarde a operação em andamento'
                    : 'Reescanear o volume de todas as músicas',
              ),
              onTap: () => _confirmRescanLoudness(context, ref),
            ),
            ListTile(
              leading: Icon(
                Icons.bar_chart_outlined,
                color: colorScheme.primary,
              ),
              title: const Text('Estatísticas'),
              subtitle: const Text('Tempo ouvido por música e artista'),
              onTap: () => _go(context, const StatisticsScreen()),
            ),
            ListTile(
              leading: Icon(Icons.trending_up, color: colorScheme.primary),
              title: const Text('Mais / Menos ouvidas'),
              subtitle: const Text('Ranking de reprodução por período'),
              onTap: () => _go(context, const MostPlayedScreen()),
            ),
            ListTile(
              leading: Icon(
                Icons.fiber_new_outlined,
                color: colorScheme.primary,
              ),
              title: const Text('Adicionadas recentemente'),
              subtitle: const Text('Músicas indexadas mais recentemente'),
              onTap: () => _go(context, const RecentlyAddedScreen()),
            ),
            ListTile(
              leading: Icon(
                Icons.settings_backup_restore_outlined,
                color: colorScheme.primary,
              ),
              title: const Text('Backup e Restauração'),
              subtitle: const Text('Exportar ou restaurar seus dados'),
              onTap: () => _go(context, const BackupRestoreScreen()),
            ),
            SizedBox(height: 16 + bottomInset),
          ],
        ),
      ),
    );
  }
}
