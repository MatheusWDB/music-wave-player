import 'package:flutter/material.dart';
import 'package:music_wave_player/components/audio_transitions_bottom_sheet.dart';
import 'package:music_wave_player/screens/backup_restore_screen.dart';
import 'package:music_wave_player/screens/equalizer_screen.dart';
import 'package:music_wave_player/screens/hidden_tracks_screen.dart';
import 'package:music_wave_player/screens/most_played_screen.dart';
import 'package:music_wave_player/screens/recently_added_screen.dart';
import 'package:music_wave_player/screens/root_directory_config_screen.dart';
import 'package:music_wave_player/screens/statistics_screen.dart';

/// Bottom sheet de menu com atalhos para as telas secundárias do app
/// (biblioteca, músicas ocultas, transições, estatísticas, backup, etc.).
class AppMenuSheet extends StatelessWidget {
  const AppMenuSheet({super.key});

  void _go(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
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
