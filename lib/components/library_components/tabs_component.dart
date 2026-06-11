import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/tabs/musics_tab.dart';
import 'package:music_wave_player/tabs/playlists_tab.dart';
import 'package:music_wave_player/tabs/artists_tab.dart';
import 'package:music_wave_player/tabs/albums_tab.dart';
import 'package:provider/provider.dart';

class TabsComponent extends StatefulWidget {
  const TabsComponent({super.key});

  @override
  State<TabsComponent> createState() => _TabsComponentState();
}

class _TabsComponentState extends State<TabsComponent>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  int _activeMenu = 0;

  static const List<String> _tabTitles = [
    'Todas as Músicas',
    'Playlists',
    'Artistas',
    'Álbuns',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildContent(List<MusicTrack> tracks, Function(int) onTrackTap) {
    switch (_activeMenu) {
      case 0:
        return MusicsTab(tracks: tracks, onTrackTap: onTrackTap);
      case 1:
        return const PlaylistsTab();
      case 2:
        // CORRIGIDO: aba de Artistas com agrupamento real
        return ArtistsTab(tracks: tracks, onTrackTap: onTrackTap);
      case 3:
        // CORRIGIDO: aba de Álbuns com agrupamento real
        return AlbumsTab(tracks: tracks, onTrackTap: onTrackTap);
      default:
        return MusicsTab(tracks: tracks, onTrackTap: onTrackTap);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Configuration>(
      builder: (context, config, child) {
        final List<MusicTrack> tracks = config.indexedTracks;
        final ColorScheme colorScheme = Theme.of(context).colorScheme;

        return Column(
          children: [
            TabBar(
              controller: _tabController,
              onTap: (value) {
                if (value == _activeMenu) return;
                setState(() => _activeMenu = value);
              },
              tabs: const [
                Tab(icon: Icon(Icons.music_note_outlined), text: "Músicas"),
                Tab(
                  icon: Icon(Icons.library_music_outlined),
                  text: "Playlists",
                ),
                Tab(icon: Icon(Icons.person_outlined), text: "Artistas"),
                Tab(icon: Icon(Icons.album_outlined), text: "Álbuns"),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(
                        _tabTitles[_activeMenu],
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    tracks.isNotEmpty
                        ? Expanded(
                            child: _buildContent(tracks, config.playTrack),
                          )
                        : Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  config.rootDirectory == null ||
                                          config.rootDirectory!.isEmpty
                                      ? "Configure o Diretório Raiz primeiro para indexar suas músicas."
                                      : "Nenhuma música encontrada. Verifique a pasta ou inicie a varredura.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
