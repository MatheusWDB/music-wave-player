import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/tabs/musics_tab.dart';
import 'package:music_wave_player/tabs/playlists_tab.dart';
import 'package:provider/provider.dart';

class TabsComponent extends StatefulWidget {
  const TabsComponent({super.key});

  @override
  State<TabsComponent> createState() => _TabBarComponentState();
}

class _TabBarComponentState extends State<TabsComponent>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  int _activeMenu = 0;
  String _subTitle = "Todas as Músicas";

  Widget _childContet(List<MusicTrack> tracks, Function(int) onTrackTap) {
    return switch (_activeMenu) {
      0 => (() {
        _subTitle = 'Todas as Músicas';
        return MusicsTab(tracks: tracks, onTrackTap: onTrackTap);
      })(),
      1 => (() {
        _subTitle = 'Playlists';
        return PlaylistsTab();
      })(),
      2 => (() {
        _subTitle = 'Artistas';
        return MusicsTab(tracks: tracks, onTrackTap: onTrackTap);
      })(),
      _ => (() {
        _subTitle = 'Álbuns';
        return MusicsTab(tracks: tracks, onTrackTap: onTrackTap);
      })(),
    };
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Configuration>(
      builder: (context, config, child) {
        final List<MusicTrack> tracks = config.indexedTracks;
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        Widget childContent = _childContet(tracks, config.playTrack);

        return Column(
          children: [
            TabBar(
              controller: _tabController,
              onTap: (value) {
                if (value == _activeMenu) return;

                setState(() {
                  _activeMenu = value;

                  childContent = _childContet(tracks, config.playTrack);
                });
              },
              tabs: [
                Column(
                  children: [Icon(Icons.music_note_outlined), Text("Músicas")],
                ),
                Column(
                  children: [
                    Icon(Icons.library_music_outlined),
                    Text("Playlists"),
                  ],
                ),
                Column(
                  children: [Icon(Icons.person_outlined), Text("Artistas")],
                ),
                Column(children: [Icon(Icons.album_outlined), Text("Álbuns")]),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Column(
                  children: [
                    Text(_subTitle),
                    tracks.isNotEmpty
                        ? Expanded(child: childContent)
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                config.rootDirectory!.isEmpty
                                    ? "Configure o Diretório Raiz primeiro para indexar suas músicas."
                                    : "Nenhuma música encontrada no diretório configurado. Verifique a pasta ou inicie a varredura.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
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
