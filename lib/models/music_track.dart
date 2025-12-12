class MusicTrack {
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
}
