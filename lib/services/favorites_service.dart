import 'package:music_wave_player/data/playlist_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _kKey = 'favorites_playlist_id';
  static const favoritesName = 'Favoritos';

  /// Retorna o ID da playlist de favoritos, criando-a se necessário.
  static Future<int> ensurePlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt(_kKey);

    if (savedId != null) {
      // Confirma que ainda existe no banco
      final playlist = await PlaylistDatabase.instance.readPlaylist(savedId);
      if (playlist != null) return savedId;
    }

    // Cria a playlist de favoritos
    final playlist = await PlaylistDatabase.instance.createPlaylist(
      favoritesName,
    );
    await prefs.setInt(_kKey, playlist.id!);
    return playlist.id!;
  }

  static Future<int?> getSavedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kKey);
  }

  static Future<bool> isFavorite(int trackId) async {
    final id = await getSavedId();
    if (id == null) return false;
    final playlist = await PlaylistDatabase.instance.readPlaylist(id);
    return playlist?.trackIds.contains(trackId) ?? false;
  }

  static Future<void> toggle(int trackId) async {
    final playlistId = await ensurePlaylist();
    final isFav = await isFavorite(trackId);
    if (isFav) {
      await PlaylistDatabase.instance.removeTrack(playlistId, trackId);
    } else {
      await PlaylistDatabase.instance.addTracks(playlistId, [trackId]);
    }
  }
}
