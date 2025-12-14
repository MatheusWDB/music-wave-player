import 'package:music_wave_player/data/music_database.dart';

class MusicTrack {
  final int? id;
  final String path;

  final String title;
  final String artist;
  final String album;

  static const List<String> supportedExtensions = [
    '.mp3',
    '.m4a',
    '.flac',
    '.ogg',
    '.wav',
  ];

  MusicTrack({
    this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
  });

  static bool isSupported(String path) {
    String lowerCasePath = path.toLowerCase();
    for (var ext in supportedExtensions) {
      if (lowerCasePath.endsWith(ext)) {
        return true;
      }
    }
    return false;
  }

  Map<String, Object?> toMap() => {
    MusicDatabase.columnPath: path,
    MusicDatabase.columnTitle: title,
    MusicDatabase.columnArtist: artist,
    MusicDatabase.columnAlbum: album,
  };

  static MusicTrack fromMap(Map<String, Object?> map) => MusicTrack(
    id: map[MusicDatabase.columnId] as int?,
    path: map[MusicDatabase.columnPath] as String,
    title: map[MusicDatabase.columnTitle] as String,
    artist: map[MusicDatabase.columnArtist] as String,
    album: map[MusicDatabase.columnAlbum] as String,
  );

  @override
  String toString() {
    return "MusicTrack: {id: $id, path: $path, title: $title, artist: $artist, album: $album}";
  }
}
