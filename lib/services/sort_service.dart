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
  albumAsc,
  albumDesc,
  addedAsc,
  addedDesc,
}

/// Campo pelo qual a lista é ordenada; a direção fica em [SortOption].
enum SortField { title, artist, album, added }

extension SortFieldLabel on SortField {
  String get label => switch (this) {
    SortField.title => 'Título',
    SortField.artist => 'Artista',
    SortField.album => 'Álbum',
    SortField.added => 'Adicionados recentemente',
  };

  /// Opção aplicada ao escolher o campo: A→Z, e mais recentes primeiro
  /// em "Adicionados recentemente".
  SortOption get defaultOption => switch (this) {
    SortField.title => SortOption.titleAsc,
    SortField.artist => SortOption.artistAsc,
    SortField.album => SortOption.albumAsc,
    SortField.added => SortOption.addedDesc,
  };
}

extension SortOptionLabel on SortOption {
  SortField get field => switch (this) {
    SortOption.titleAsc || SortOption.titleDesc => SortField.title,
    SortOption.artistAsc || SortOption.artistDesc => SortField.artist,
    SortOption.albumAsc || SortOption.albumDesc => SortField.album,
    SortOption.addedAsc || SortOption.addedDesc => SortField.added,
  };

  bool get isAscending =>
      this == SortOption.titleAsc ||
      this == SortOption.artistAsc ||
      this == SortOption.albumAsc ||
      this == SortOption.addedAsc;

  /// Mesma opção com a direção invertida.
  SortOption get reversed => switch (this) {
    SortOption.titleAsc => SortOption.titleDesc,
    SortOption.titleDesc => SortOption.titleAsc,
    SortOption.artistAsc => SortOption.artistDesc,
    SortOption.artistDesc => SortOption.artistAsc,
    SortOption.albumAsc => SortOption.albumDesc,
    SortOption.albumDesc => SortOption.albumAsc,
    SortOption.addedAsc => SortOption.addedDesc,
    SortOption.addedDesc => SortOption.addedAsc,
  };

  String get label => field.label;

  String get key => name;

  /// Chaves antigas salvas (ex.: `random`, `ratingDesc`) caem no [fallback].
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
    int compareText(String a, String b) =>
        MusicDatabase.naturalCompare(a.toLowerCase(), b.toLowerCase());
    int addedMillis(MusicTrack t) => t.addedAt?.millisecondsSinceEpoch ?? 0;

    final int Function(MusicTrack, MusicTrack) compare = switch (option.field) {
      SortField.title => (a, b) => compareText(a.title, b.title),
      SortField.artist => (a, b) => compareText(a.artist, b.artist),
      SortField.album => (a, b) => compareText(a.album, b.album),
      SortField.added => (a, b) => addedMillis(a).compareTo(addedMillis(b)),
    };

    final list = List<MusicTrack>.of(tracks);
    list.sort((a, b) {
      final result = option.isAscending ? compare(a, b) : compare(b, a);
      // Desempate por título para manter a ordem estável entre campos iguais
      // (ex.: faixas indexadas no mesmo instante).
      return result != 0 ? result : compareText(a.title, b.title);
    });
    return list;
  }
}
