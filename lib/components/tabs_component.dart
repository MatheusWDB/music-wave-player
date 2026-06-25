import 'package:flutter/material.dart';
import 'package:music_wave_player/components/sort_button.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/tabs/musics_tab.dart';
import 'package:music_wave_player/tabs/artists_tab.dart';
import 'package:music_wave_player/tabs/albums_tab.dart';
import 'package:music_wave_player/tabs/playlists_tab.dart';
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

  static const _sortOptionsMusics = [
    SortOption.titleAsc,
    SortOption.titleDesc,
    SortOption.artistAsc,
    SortOption.artistDesc,
    SortOption.ratingDesc,
    SortOption.ratingAsc,
    SortOption.random,
  ];
  static const _sortOptionsPlaylists = [
    SortOption.titleAsc,
    SortOption.titleDesc,
  ];
  static const _sortOptionsArtists = [
    SortOption.titleAsc,
    SortOption.titleDesc,
  ];
  static const _sortOptionsAlbums = [
    SortOption.titleAsc,
    SortOption.titleDesc,
    SortOption.artistAsc,
    SortOption.artistDesc,
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

  Widget _buildContent(
    List<MusicTrack> tracks,
    Future<void> Function(int) onTrackTap,
    Configuration config,
  ) {
    switch (_activeMenu) {
      case 0:
        return MusicsTab(
          tracks: config.applySortToTracks(tracks, config.sortMusics),
          onTrackTap: onTrackTap,
        );
      case 1:
        return PlaylistsTab(sortOption: config.sortPlaylists);
      case 2:
        return ArtistsTab(
          tracks: config.applySortToTracks(tracks, config.sortArtists),
          onTrackTap: onTrackTap,
        );
      case 3:
        return AlbumsTab(
          tracks: config.applySortToTracks(tracks, config.sortAlbums),
          onTrackTap: onTrackTap,
        );
      default:
        return MusicsTab(tracks: tracks, onTrackTap: onTrackTap);
    }
  }

  SortOption _currentSort(Configuration config) => switch (_activeMenu) {
    0 => config.sortMusics,
    1 => config.sortPlaylists,
    2 => config.sortArtists,
    3 => config.sortAlbums,
    _ => config.sortMusics,
  };

  List<SortOption> _currentOptions() => switch (_activeMenu) {
    0 => _sortOptionsMusics,
    1 => _sortOptionsPlaylists,
    2 => _sortOptionsArtists,
    3 => _sortOptionsAlbums,
    _ => _sortOptionsMusics,
  };

  void _onSortSelected(SortOption option, Configuration config) {
    switch (_activeMenu) {
      case 0:
        config.setSortMusics(option);
      case 1:
        config.setSortPlaylists(option);
      case 2:
        config.setSortArtists(option);
      case 3:
        config.setSortAlbums(option);
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
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _tabTitles[_activeMenu],
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SortButton(
                            current: _currentSort(config),
                            options: _currentOptions(),
                            onSelected: (opt) => _onSortSelected(opt, config),
                          ),
                        ],
                      ),
                    ),
                    tracks.isNotEmpty
                        ? Expanded(
                            child: _buildContent(
                              tracks,
                              config.playTrack,
                              config,
                            ),
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
