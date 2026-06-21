import 'package:flutter/material.dart';
import 'package:music_wave_player/components/library_components/mini_player_component.dart';
import 'package:music_wave_player/components/library_components/tabs_component.dart';
import 'package:music_wave_player/components/recap_widget.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/screens/hidden_tracks_screen.dart';
import 'package:music_wave_player/screens/recently_played_screen.dart';
import 'package:music_wave_player/screens/root_directory_config_screen.dart';
import 'package:music_wave_player/screens/search_screen.dart';
import 'package:music_wave_player/screens/statistics_screen.dart';
import 'package:music_wave_player/services/recap_service.dart';
import 'package:provider/provider.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecap());
  }

  Future<void> _checkRecap() async {
    final config = context.read<Configuration>();
    if (config.indexedTracks.isEmpty) return;

    final recap = await RecapService.checkPendingRecap(config.indexedTracks);
    if (recap != null && mounted) {
      await RecapWidget.show(context, recap);
    }
  }

  void _openSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SettingsMenu(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'LocalPlay',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecentlyPlayedScreen(),
                      ),
                    ),
                    icon: Icon(Icons.history, color: colorScheme.onSurface),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                    icon: Icon(Icons.search, color: colorScheme.onSurface),
                  ),
                  IconButton(
                    onPressed: () => _openSettingsMenu(context),
                    icon: Icon(Icons.settings, color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            const Expanded(child: TabsComponent()),
            const Padding(
              padding: EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 8.0),
              child: MiniPlayerComponent(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RootDirectoryConfigScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(
              Icons.visibility_off_outlined,
              color: colorScheme.primary,
            ),
            title: const Text('Músicas ocultas'),
            subtitle: const Text('Ver e reexibir músicas ocultadas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HiddenTracksScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.bar_chart_outlined, color: colorScheme.primary),
            title: const Text('Estatísticas'),
            subtitle: const Text('Tempo ouvido por música e artista'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            },
          ),
          SizedBox(height: 16 + bottomInset),
        ],
      ),
    );
  }
}
