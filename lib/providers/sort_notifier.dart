import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_wave_player/services/sort_service.dart';

part 'sort_notifier.g.dart';

const String _kSortMusicsKey = 'sort_musics';
const String _kSortPlaylistsKey = 'sort_playlists';
const String _kSortAlbumsKey = 'sort_albums';
const String _kSortArtistsKey = 'sort_artists';

/// Estado imutável das preferências de ordenação de cada aba.
class SortState {
  final SortOption musics;
  final SortOption playlists;
  final SortOption albums;
  final SortOption artists;

  const SortState({
    required this.musics,
    required this.playlists,
    required this.albums,
    required this.artists,
  });

  SortState copyWith({
    SortOption? musics,
    SortOption? playlists,
    SortOption? albums,
    SortOption? artists,
  }) {
    return SortState(
      musics: musics ?? this.musics,
      playlists: playlists ?? this.playlists,
      albums: albums ?? this.albums,
      artists: artists ?? this.artists,
    );
  }
}

/// Gerencia as preferências de ordenação por aba, com persistência em
/// [SharedPreferences]. Substitui a parte de estado do antigo [SortService]
/// — a aplicação da ordenação em si continua em [SortService.apply],
/// que é uma função pura sem estado.
@Riverpod(keepAlive: true)
class SortNotifier extends _$SortNotifier {
  @override
  Future<SortState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SortState(
      musics: SortOptionLabel.fromKey(
        prefs.getString(_kSortMusicsKey) ?? '',
        SortOption.titleAsc,
      ),
      playlists: SortOptionLabel.fromKey(
        prefs.getString(_kSortPlaylistsKey) ?? '',
        SortOption.titleAsc,
      ),
      albums: SortOptionLabel.fromKey(
        prefs.getString(_kSortAlbumsKey) ?? '',
        SortOption.titleAsc,
      ),
      artists: SortOptionLabel.fromKey(
        prefs.getString(_kSortArtistsKey) ?? '',
        SortOption.titleAsc,
      ),
    );
  }

  Future<void> setSortMusics(SortOption option) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(musics: option));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSortMusicsKey, option.key);
  }

  Future<void> setSortPlaylists(SortOption option) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(playlists: option));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSortPlaylistsKey, option.key);
  }

  Future<void> setSortAlbums(SortOption option) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(albums: option));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSortAlbumsKey, option.key);
  }

  Future<void> setSortArtists(SortOption option) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(artists: option));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSortArtistsKey, option.key);
  }
}
