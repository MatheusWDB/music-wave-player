import 'package:music_wave_player/data/music_database.dart';

class MusicTrack {
  final int? id;
  final String path;
  final String title;
  final String artist;
  final String album;

  /// true = metadados foram editados manualmente pelo usuário.
  /// O indexador respeita esse flag e não sobrescreve os dados.
  final bool isEdited;

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
    this.isEdited = false,
  });

  MusicTrack copyWith({
    int? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    bool? isEdited,
  }) {
    return MusicTrack(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  static bool isSupported(String path) {
    final lower = path.toLowerCase();
    return supportedExtensions.any((ext) => lower.endsWith(ext));
  }

  Map<String, Object?> toMap() => {
    MusicDatabase.columnPath: path,
    MusicDatabase.columnTitle: title,
    MusicDatabase.columnArtist: artist,
    MusicDatabase.columnAlbum: album,
    MusicDatabase.columnIsEdited: isEdited ? 1 : 0,
  };

  static MusicTrack fromMap(Map<String, Object?> map) => MusicTrack(
    id: map[MusicDatabase.columnId] as int?,
    path: map[MusicDatabase.columnPath] as String,
    title: map[MusicDatabase.columnTitle] as String,
    artist: map[MusicDatabase.columnArtist] as String,
    album: map[MusicDatabase.columnAlbum] as String,
    isEdited: (map[MusicDatabase.columnIsEdited] as int? ?? 0) == 1,
  );

  @override
  String toString() =>
      'MusicTrack: {id: $id, path: $path, title: $title, '
      'artist: $artist, album: $album, isEdited: $isEdited}';
}
