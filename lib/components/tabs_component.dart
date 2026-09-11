import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/tabs_sort_header.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/providers/playback_notifier.dart';
import 'package:music_wave_player/providers/sort_notifier.dart';
import 'package:music_wave_player/services/sort_service.dart';
import 'package:music_wave_player/tabs/musics_tab.dart';
import 'package:music_wave_player/tabs/artists_tab.dart';
import 'package:music_wave_player/tabs/albums_tab.dart';
import 'package:music_wave_player/tabs/playlists_tab.dart';

class TabsComponent extends ConsumerWidget {
  const TabsComponent({super.key, required this.activeIndex});

  /// Índice do destino ativo (0: Músicas, 1: Playlists, 2: Artistas,
  /// 3: Álbuns), controlado pelo [LibraryBottomNav] no widget pai.
  final int activeIndex;

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

  Future<void> _onTrackTap(
    WidgetRef ref,
    int trackId,
    List<MusicTrack> tracks,
  ) async {
    final track = tracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return;
    await ref
        .read(playbackNotifierProvider.notifier)
        .playTrack(trackId, indexedTracks: tracks, trackPath: track.path);
  }

  Widget _buildContent(WidgetRef ref, List<MusicTrack> tracks, SortState sort) {
    switch (activeIndex) {
      case 0:
        return MusicsTab(
          tracks: SortService.apply(tracks, sort.musics),
          onTrackTap: (id) => _onTrackTap(ref, id, tracks),
        );
      case 1:
        return PlaylistsTab(sortOption: sort.playlists);
      case 2:
        return ArtistsTab(
          tracks: SortService.apply(tracks, sort.artists),
          onTrackTap: (id) => _onTrackTap(ref, id, tracks),
        );
      case 3:
        return AlbumsTab(
          tracks: SortService.apply(tracks, sort.albums),
          onTrackTap: (id) => _onTrackTap(ref, id, tracks),
        );
      default:
        return MusicsTab(
          tracks: tracks,
          onTrackTap: (id) => _onTrackTap(ref, id, tracks),
        );
    }
  }

  SortOption _currentSort(SortState sort) => switch (activeIndex) {
    0 => sort.musics,
    1 => sort.playlists,
    2 => sort.artists,
    3 => sort.albums,
    _ => sort.musics,
  };

  List<SortOption> _currentOptions() => switch (activeIndex) {
    0 => _sortOptionsMusics,
    1 => _sortOptionsPlaylists,
    2 => _sortOptionsArtists,
    3 => _sortOptionsAlbums,
    _ => _sortOptionsMusics,
  };

  void _onSortSelected(WidgetRef ref, SortOption option) {
    final notifier = ref.read(sortNotifierProvider.notifier);
    switch (activeIndex) {
      case 0:
        notifier.setSortMusics(option);
      case 1:
        notifier.setSortPlaylists(option);
      case 2:
        notifier.setSortArtists(option);
      case 3:
        notifier.setSortAlbums(option);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indexingState = ref.watch(indexingNotifierProvider).valueOrNull;
    final sortState = ref.watch(sortNotifierProvider).valueOrNull;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (indexingState == null || sortState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final tracks = indexingState.indexedTracks;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabsSortHeader(
            title: _tabTitles[activeIndex],
            currentSort: _currentSort(sortState),
            sortOptions: _currentOptions(),
            onSortSelected: (option) => _onSortSelected(ref, option),
          ),
          tracks.isNotEmpty
              ? Expanded(child: _buildContent(ref, tracks, sortState))
              : Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        indexingState.rootDirectory == null ||
                                indexingState.rootDirectory!.isEmpty
                            ? "Configure o Diretório Raiz primeiro para indexar suas músicas."
                            : "Nenhuma música encontrada. Verifique a pasta ou inicie a varredura.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
