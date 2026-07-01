import 'package:music_wave_player/data/music_database.dart';

class MusicTrack {
  final int? id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final bool isEdited;
  final bool isHidden;
  final String? coverPath;
  final int durationMs;
  final double rating;
  final DateTime? addedAt;
  final double? loudnessLufs;

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
    this.isHidden = false,
    this.coverPath,
    this.durationMs = 0,
    this.rating = 0,
    this.addedAt,
    this.loudnessLufs,
  });

  MusicTrack copyWith({
    int? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    bool? isEdited,
    bool? isHidden,
    String? coverPath,
    bool clearCoverPath = false,
    int? durationMs,
    double? rating,
    DateTime? addedAt,
    double? loudnessLufs,
  }) {
    return MusicTrack(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      isEdited: isEdited ?? this.isEdited,
      isHidden: isHidden ?? this.isHidden,
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
      durationMs: durationMs ?? this.durationMs,
      rating: rating ?? this.rating,
      addedAt: addedAt ?? this.addedAt,
      loudnessLufs: loudnessLufs ?? this.loudnessLufs,
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
    MusicDatabase.columnIsHidden: isHidden ? 1 : 0,
    MusicDatabase.columnCoverPath: coverPath,
    MusicDatabase.columnDurationMs: durationMs,
    MusicDatabase.columnRating: rating,
    MusicDatabase.columnAddedAt: addedAt?.toIso8601String(),
    MusicDatabase.columnLoudnessLufs: loudnessLufs,
  };

  static MusicTrack fromMap(Map<String, Object?> map) => MusicTrack(
    id: map[MusicDatabase.columnId] as int?,
    path: map[MusicDatabase.columnPath] as String,
    title: map[MusicDatabase.columnTitle] as String,
    artist: map[MusicDatabase.columnArtist] as String,
    album: map[MusicDatabase.columnAlbum] as String,
    isEdited: (map[MusicDatabase.columnIsEdited] as int? ?? 0) == 1,
    isHidden: (map[MusicDatabase.columnIsHidden] as int? ?? 0) == 1,
    coverPath: map[MusicDatabase.columnCoverPath] as String?,
    durationMs: map[MusicDatabase.columnDurationMs] as int? ?? 0,
    rating: (map[MusicDatabase.columnRating] as num? ?? 0).toDouble(),
    addedAt: map[MusicDatabase.columnAddedAt] != null
        ? DateTime.tryParse(map[MusicDatabase.columnAddedAt] as String)
        : null,
    loudnessLufs: (map[MusicDatabase.columnLoudnessLufs] as num?)?.toDouble(),
  );

  @override
  String toString() =>
      'MusicTrack: {id: $id, path: $path, title: $title, '
      'artist: $artist, album: $album, isEdited: $isEdited, '
      'isHidden: $isHidden, rating: $rating, coverPath: $coverPath, '
      'durationMs: $durationMs, addedAt: $addedAt, '
      'loudnessLufs: $loudnessLufs}';
}
