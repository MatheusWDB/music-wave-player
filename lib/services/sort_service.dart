import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kSortMusicsKey = 'sort_musics';
const String _kSortPlaylistsKey = 'sort_playlists';
const String _kSortAlbumsKey = 'sort_albums';
const String _kSortArtistsKey = 'sort_artists';

enum SortOption {
  titleAsc,
  titleDesc,
  artistAsc,
  artistDesc,
  random,
  ratingDesc,
  ratingAsc,
}

extension SortOptionLabel on SortOption {
  String get label => switch (this) {
    SortOption.titleAsc => 'Título (A→Z)',
    SortOption.titleDesc => 'Título (Z→A)',
    SortOption.artistAsc => 'Artista (A→Z)',
    SortOption.artistDesc => 'Artista (Z→A)',
    SortOption.random => 'Aleatório',
    SortOption.ratingDesc => 'Melhor avaliadas',
    SortOption.ratingAsc => 'Pior avaliadas',
  };

  String get key => name;

  static SortOption fromKey(String key, SortOption fallback) {
    return SortOption.values.firstWhere(
      (e) => e.name == key,
      orElse: () => fallback,
    );
  }
}

/// Gerencia as preferências de ordenação por aba e aplica a ordenação
/// sobre listas de faixas.
///
/// No Riverpod, vira um [Notifier] com estado imutável de quatro [SortOption].
class SortService {
  SortOption _sortMusics = SortOption.titleAsc;
  SortOption _sortPlaylists = SortOption.titleAsc;
  SortOption _sortAlbums = SortOption.titleAsc;
  SortOption _sortArtists = SortOption.titleAsc;

  /// Chamado sempre que uma opção de sort muda, para que o
  /// [Configuration] possa emitir [notifyListeners].
  final void Function() onStateChanged;

  SortService({required this.onStateChanged});

  // ── Getters ───────────────────────────────────────────────────────────────

  SortOption get sortMusics => _sortMusics;
  SortOption get sortPlaylists => _sortPlaylists;
  SortOption get sortAlbums => _sortAlbums;
  SortOption get sortArtists => _sortArtists;

  // ── Inicialização ─────────────────────────────────────────────────────────

  void init({
    required SortOption musics,
    required SortOption playlists,
    required SortOption albums,
    required SortOption artists,
  }) {
    _sortMusics = musics;
    _sortPlaylists = playlists;
    _sortAlbums = albums;
    _sortArtists = artists;
  }

  // ── Setters com persistência ──────────────────────────────────────────────

  Future<void> setSortMusics(SortOption option) async {
    _sortMusics = option;
    onStateChanged();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSortMusicsKey, option.key);
  }

  Future<void> setSortPlaylists(SortOption option) async {
    _sortPlaylists = option;
    onStateChanged();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSortPlaylistsKey, option.key);
  }

  Future<void> setSortAlbums(SortOption option) async {
    _sortAlbums = option;
    onStateChanged();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSortAlbumsKey, option.key);
  }

  Future<void> setSortArtists(SortOption option) async {
    _sortArtists = option;
    onStateChanged();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSortArtistsKey, option.key);
  }

  // ── Aplicação de ordenação ────────────────────────────────────────────────

  /// Retorna uma cópia da lista ordenada conforme [option].
  /// Método puro — sem efeitos colaterais.
  static List<MusicTrack> apply(List<MusicTrack> tracks, SortOption option) {
    final list = List<MusicTrack>.of(tracks);
    switch (option) {
      case SortOption.titleAsc:
        list.sort(
          (a, b) => MusicDatabase.naturalCompare(
            a.title.toLowerCase(),
            b.title.toLowerCase(),
          ),
        );
      case SortOption.titleDesc:
        list.sort(
          (a, b) => MusicDatabase.naturalCompare(
            b.title.toLowerCase(),
            a.title.toLowerCase(),
          ),
        );
      case SortOption.artistAsc:
        list.sort(
          (a, b) => MusicDatabase.naturalCompare(
            a.artist.toLowerCase(),
            b.artist.toLowerCase(),
          ),
        );
      case SortOption.artistDesc:
        list.sort(
          (a, b) => MusicDatabase.naturalCompare(
            b.artist.toLowerCase(),
            a.artist.toLowerCase(),
          ),
        );
      case SortOption.random:
        list.shuffle();
      case SortOption.ratingDesc:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case SortOption.ratingAsc:
        list.sort((a, b) => a.rating.compareTo(b.rating));
    }
    return list;
  }
}
