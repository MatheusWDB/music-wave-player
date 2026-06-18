import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/models/playlist.dart';
import 'package:music_wave_player/services/cover_art_service.dart';
import 'package:music_wave_player/services/ffmpeg_service.dart';
import 'package:music_wave_player/services/saf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kRootDirectoryKey = 'rootDirectoryPath';
const String _kLastScanDateKey = 'lastScanDate';
const String _kLastPlayedMusicIdKey = 'lastPlayedMusicId';
const String _kLastSeekPositionMsKey = 'lastSeekPositionMs';

enum IndexingStatus { idle, scanning, complete, error }

Future<List<String>> _scanDirectoryForPaths(String rootPath) async {
  final paths = <String>[];
  final dir = Directory(rootPath);
  if (!await dir.exists()) return paths;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File && MusicTrack.isSupported(entity.path)) {
      paths.add(entity.path);
    }
  }
  return paths;
}

Future<List<MusicTrack>> _buildTracksFromPaths(List<String> paths) async {
  final tracks = <MusicTrack>[];
  for (final path in paths) {
    tracks.add(await _extractMetadata(path));
  }
  return tracks;
}

Future<MusicTrack> _extractMetadata(String path) async {
  String title = _cleanFilename(path);
  String artist = 'Artista Desconhecido';
  String album = 'Álbum Desconhecido';

  final lower = path.toLowerCase();
  try {
    if (lower.endsWith('.mp3')) {
      final tags = await _readId3v2(File(path));
      if (tags['title'] != null) title = tags['title']!;
      if (tags['artist'] != null) artist = tags['artist']!;
      if (tags['album'] != null) album = tags['album']!;
    } else if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) {
      final tags = await _readMp4Metadata(path);
      if (tags['title'] != null) title = tags['title']!;
      if (tags['artist'] != null) artist = tags['artist']!;
      if (tags['album'] != null) album = tags['album']!;
    }
  } catch (_) {}

  final coverPath = await CoverArtService.extractAndSave(path);
  return MusicTrack(
    path: path,
    title: title,
    artist: artist,
    album: album,
    coverPath: coverPath,
  );
}

String _cleanFilename(String path) {
  String name = path.split(Platform.pathSeparator).last;
  if (name.contains('.')) name = name.substring(0, name.lastIndexOf('.'));
  name = name.replaceFirst(RegExp(r'^\d{1,3}[\s._-]+'), '');
  name = name.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return name.isEmpty ? 'Faixa Desconhecida' : name;
}

Future<Map<String, String?>> _readId3v2(File file) async {
  final result = <String, String?>{};
  final raf = await file.open(mode: FileMode.read);
  try {
    final header = await raf.read(10);
    if (header[0] != 0x49 || header[1] != 0x44 || header[2] != 0x33)
      return result;
    final tagSize =
        ((header[6] & 0x7F) << 21) |
        ((header[7] & 0x7F) << 14) |
        ((header[8] & 0x7F) << 7) |
        (header[9] & 0x7F);
    final tagData = await raf.read(tagSize);
    int pos = 0;
    while (pos + 10 <= tagData.length) {
      final frameId = String.fromCharCodes(tagData.sublist(pos, pos + 4));
      if (frameId == '\x00\x00\x00\x00') break;
      final frameSize =
          (tagData[pos + 4] << 24) |
          (tagData[pos + 5] << 16) |
          (tagData[pos + 6] << 8) |
          tagData[pos + 7];
      pos += 10;
      if (frameSize <= 0 || pos + frameSize > tagData.length) break;
      if (frameId == 'TIT2' || frameId == 'TPE1' || frameId == 'TALB') {
        final encoding = tagData[pos];
        final contentBytes = tagData.sublist(pos + 1, pos + frameSize);
        String text;
        if (encoding == 1 || encoding == 2) {
          final bom = contentBytes.length >= 2
              ? (contentBytes[0] << 8 | contentBytes[1])
              : 0;
          final start = (bom == 0xFFFE || bom == 0xFEFF) ? 2 : 0;
          text = _decodeUtf16(contentBytes.sublist(start));
        } else {
          text = String.fromCharCodes(contentBytes.where((b) => b != 0));
        }
        text = text.trim();
        if (text.isNotEmpty) {
          if (frameId == 'TIT2') result['title'] = text;
          if (frameId == 'TPE1') result['artist'] = text;
          if (frameId == 'TALB') result['album'] = text;
        }
      }
      pos += frameSize;
    }
  } finally {
    await raf.close();
  }
  return result;
}

String _decodeUtf16(List<int> bytes) {
  final buffer = StringBuffer();
  for (int i = 0; i + 1 < bytes.length; i += 2) {
    final cu = bytes[i] | (bytes[i + 1] << 8);
    if (cu == 0) break;
    buffer.writeCharCode(cu);
  }
  return buffer.toString();
}

Future<Map<String, String?>> _readMp4Metadata(String path) async {
  final result = <String, String?>{};
  final file = File(path);
  if (!await file.exists()) return result;
  final bytes = await file.readAsBytes();
  _parseMp4Boxes(bytes, 0, bytes.length, result);
  return result;
}

void _parseMp4Boxes(
  List<int> bytes,
  int offset,
  int limit,
  Map<String, String?> result,
) {
  int pos = offset;
  while (pos + 8 <= limit) {
    final size = _readUint32BE(bytes, pos);
    if (size < 8 || pos + size > limit) break;
    final name = String.fromCharCodes(
      bytes.sublist(pos + 4, pos + 8).map((b) => b & 0xFF),
    );
    if (name == '\u00A9nam' || name == '©nam') {
      result['title'] = _readItunesStringBox(bytes, pos + 8, pos + size);
    } else if (name == '\u00A9ART' || name == '©ART') {
      result['artist'] = _readItunesStringBox(bytes, pos + 8, pos + size);
    } else if (name == '\u00A9alb' || name == '©alb') {
      result['album'] = _readItunesStringBox(bytes, pos + 8, pos + size);
    }
    if (_isMp4Container(name)) {
      int innerOffset = pos + 8;
      if (name == 'meta') innerOffset += 4;
      _parseMp4Boxes(bytes, innerOffset, pos + size, result);
    }
    pos += size;
    if (result['title'] != null &&
        result['artist'] != null &&
        result['album'] != null)
      break;
  }
}

String? _readItunesStringBox(List<int> bytes, int offset, int limit) {
  int pos = offset;
  while (pos + 8 <= limit) {
    final size = _readUint32BE(bytes, pos);
    if (size < 8 || pos + size > limit) break;
    final name = String.fromCharCodes(
      bytes.sublist(pos + 4, pos + 8).map((b) => b & 0xFF),
    );
    if (name == 'data' && size > 16) {
      final text = String.fromCharCodes(
        bytes.sublist(pos + 16, pos + size),
      ).trim();
      return text.isNotEmpty ? text : null;
    }
    pos += size;
  }
  return null;
}

bool _isMp4Container(String name) {
  const containers = {
    'moov',
    'udta',
    'meta',
    'ilst',
    'trak',
    'mdia',
    'minf',
    'stbl',
    'edts',
    'dinf',
    'sinf',
  };
  return containers.contains(name);
}

int _readUint32BE(List<int> bytes, int offset) {
  return ((bytes[offset] & 0xFF) << 24) |
      ((bytes[offset + 1] & 0xFF) << 16) |
      ((bytes[offset + 2] & 0xFF) << 8) |
      (bytes[offset + 3] & 0xFF);
}

class Configuration with ChangeNotifier, DiagnosticableTreeMixin {
  String? _rootDirectory;
  DateTime? _lastScanDate;
  IndexingStatus _indexingStatus = IndexingStatus.idle;
  List<MusicTrack> _indexedTracks = [];
  int _indexedFileCount = 0;
  int? _lastPlayedMusicId;
  int _lastSeekPositionMs = 0;
  bool _isShuffleActive = false;
  String _repeatMode = 'Off';
  bool _isPlaying = false;
  List<int> _playbackQueue = [];
  int _currentQueueIndex = -1;
  int _currentPositionMs = 0;
  int _trackDurationMs = 0;
  AudioHandler? _audioHandler;
  bool _isLoading = true;

  static const _safChannel = MethodChannel(
    'br.com.hematsu.music_wave_player/saf',
  );

  Configuration.empty();

  bool get isLoading => _isLoading;

  Future<void> loadFromStorageAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _rootDirectory = prefs.getString(_kRootDirectoryKey);
      final ts = prefs.getInt(_kLastScanDateKey);
      _lastScanDate = ts != null
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : null;
      _lastPlayedMusicId = prefs.getInt(_kLastPlayedMusicIdKey);
      _lastSeekPositionMs = prefs.getInt(_kLastSeekPositionMsKey) ?? 0;
      await loadIndexedTracks();
      if (_lastPlayedMusicId != null && currentTrackPath != null) {
        await _audioHandler?.customAction('loadTrack', {
          'path': currentTrackPath,
        });
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? get rootDirectory => _rootDirectory;
  DateTime? get lastScanDate => _lastScanDate;
  IndexingStatus get indexingStatus => _indexingStatus;
  int get indexedFileCount => _indexedFileCount;
  List<MusicTrack> get indexedTracks => _indexedTracks;
  int? get lastPlayedMusicId => _lastPlayedMusicId;
  int get lastSeekPositionMs => _lastSeekPositionMs;
  bool get isShuffleActive => _isShuffleActive;
  String get repeatMode => _repeatMode;
  bool get isPlaying => _isPlaying;
  int get currentQueueIndex => _currentQueueIndex;
  List<int> get playbackQueue => List.unmodifiable(_playbackQueue);
  int get currentPositionMs => _currentPositionMs;
  int get trackDurationMs => _trackDurationMs;
  String? get currentTrackPath => currentTrack?.path;
  AudioHandler? get audioHandler => _audioHandler;

  MusicTrack? get currentTrack {
    if (_lastPlayedMusicId == null) return null;
    try {
      return _indexedTracks.firstWhere((t) => t.id == _lastPlayedMusicId);
    } catch (_) {
      return null;
    }
  }

  set rootDirectory(String path) {
    if (_rootDirectory == path) return;
    _rootDirectory = path;
    _indexingStatus = IndexingStatus.idle;
    notifyListeners();
    _saveRootDirectory(path);
  }

  set audioHandler(AudioHandler handler) => _audioHandler = handler;
  set lastSeekPositionMs(int ms) => _lastSeekPositionMs = ms;

  void syncPlayingState(bool playing) {
    if (_isPlaying != playing) {
      _isPlaying = playing;
      notifyListeners();
    }
  }

  void updateCurrentPosition(int ms) {
    if (_currentPositionMs != ms) {
      _currentPositionMs = ms;
      notifyListeners();
    }
  }

  void updateTrackDuration(int ms) {
    if (_trackDurationMs != ms) {
      _trackDurationMs = ms;
      notifyListeners();
    }
  }

  void seekTo(int ms) => _audioHandler?.seek(Duration(milliseconds: ms));

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final id = _playbackQueue.removeAt(oldIndex);
    _playbackQueue.insert(newIndex, id);
    _currentQueueIndex = _playbackQueue.indexOf(_lastPlayedMusicId!);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _playbackQueue.length) return;
    final removingCurrent = index == _currentQueueIndex;
    _playbackQueue.removeAt(index);
    if (removingCurrent) {
      // Se removeu a atual, toca a próxima (ou para se ficou vazia)
      if (_playbackQueue.isEmpty) {
        _lastPlayedMusicId = null;
        _currentQueueIndex = -1;
        _audioHandler?.pause();
      } else {
        _currentQueueIndex = index.clamp(0, _playbackQueue.length - 1);
        playTrack(_playbackQueue[_currentQueueIndex], regenerateQueue: false);
      }
    } else {
      _currentQueueIndex = _playbackQueue.indexOf(_lastPlayedMusicId!);
    }
    notifyListeners();
  }

  void jumpToQueueIndex(int index) {
    if (index < 0 || index >= _playbackQueue.length) return;
    _currentQueueIndex = index;
    playTrack(_playbackQueue[index], regenerateQueue: false);
  }

  Future<void> _triggerMediaScan(String dirPath) async {
    try {
      await _safChannel.invokeMethod('scanMedia', {'path': dirPath});
    } catch (_) {}
  }

  // ── Playlist ──────────────────────────────────────────────────────────────

  /// Insere as faixas da playlist na fila imediatamente após a música atual,
  /// descartando o que viria depois. Começa a tocar a primeira faixa da playlist.
  void playPlaylist(Playlist playlist) {
    if (playlist.trackIds.isEmpty) return;

    final validIds = playlist.trackIds
        .where((id) => _indexedTracks.any((t) => t.id == id))
        .toList();
    if (validIds.isEmpty) return;

    _playbackQueue = List.of(validIds);
    _currentQueueIndex = 0;

    final firstId = validIds.first;
    _lastPlayedMusicId = firstId;
    _saveLastPlayedMusicId(firstId);
    _lastSeekPositionMs = 0;
    _currentPositionMs = 0;
    _trackDurationMs = 0;
    _audioHandler?.customAction('loadTrack', {'path': currentTrackPath});
    _isPlaying = true;
    notifyListeners();
    _audioHandler?.play();
  }

  /// Toca uma lista arbitrária de faixas (artista, álbum, etc.),
  /// substituindo a fila atual.
  void playTracks(List<MusicTrack> tracks) {
    if (tracks.isEmpty) return;
    _playbackQueue = tracks.map((t) => t.id!).toList();
    _currentQueueIndex = 0;
    _lastPlayedMusicId = tracks.first.id;
    _saveLastPlayedMusicId(tracks.first.id!);
    _lastSeekPositionMs = 0;
    _currentPositionMs = 0;
    _trackDurationMs = 0;
    _audioHandler?.customAction('loadTrack', {'path': currentTrackPath});
    _isPlaying = true;
    notifyListeners();
    _audioHandler?.play();
  }

  // ── Edição de metadados ───────────────────────────────────────────────────

  Future<bool> editTrack({
    required MusicTrack track,
    required String newTitle,
    required String newArtist,
    required String newAlbum,
    required BuildContext context,
  }) async {
    String? folderUri = await SafService.ensureAccess();
    if (folderUri == null) {
      if (context.mounted)
        _showSnack(context, 'Acesso à pasta negado. Edição cancelada.');
      return false;
    }
    final tempPath = await FfmpegService.writeMetadata(
      inputPath: track.path,
      title: newTitle,
      artist: newArtist,
      album: newAlbum,
    );
    if (tempPath == null) {
      if (context.mounted)
        _showSnack(context, 'Erro ao processar o arquivo. Tente novamente.');
      return false;
    }
    final fileName = track.path.split('/').last;
    final copied = await SafService.copyTempToSaf(
      tempPath: tempPath,
      targetFileName: fileName,
      folderUri: folderUri,
    );
    try {
      await File(tempPath).delete();
    } catch (_) {}
    if (!copied) {
      if (context.mounted)
        _showSnack(context, 'Erro ao salvar o arquivo. Tente novamente.');
      return false;
    }
    await MusicDatabase.instance.updateTrack(
      id: track.id!,
      title: newTitle,
      artist: newArtist,
      album: newAlbum,
    );
    final idx = _indexedTracks.indexWhere((t) => t.id == track.id);
    if (idx != -1) {
      _indexedTracks[idx] = track.copyWith(
        title: newTitle,
        artist: newArtist,
        album: newAlbum,
        isEdited: true,
      );
      _indexedTracks.sort(
        (a, b) => MusicDatabase.naturalCompare(
          a.title.toLowerCase(),
          b.title.toLowerCase(),
        ),
      );
      notifyListeners();
    }
    if (_lastPlayedMusicId == track.id) {
      await _audioHandler?.customAction('loadTrack', {'path': track.path});
    }
    if (context.mounted)
      _showSnack(context, 'Informações salvas com sucesso!', isSuccess: true);
    return true;
  }

  void _showSnack(
    BuildContext context,
    String message, {
    bool isSuccess = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveLastPlayedMusicId(int id) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastPlayedMusicIdKey, id);
  }

  Future<void> _saveLastSeekPosition(int ms) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastSeekPositionMsKey, ms);
  }

  Future<void> saveCurrentPositionForResume(int ms) async {
    _lastSeekPositionMs = ms;
    await _saveLastSeekPosition(ms);
  }

  Future<void> _saveLastScanDate(DateTime d) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastScanDateKey, d.millisecondsSinceEpoch);
  }

  Future<void> _saveRootDirectory(String path) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRootDirectoryKey, path);
  }

  void _regenerateQueue() {
    final ids = _indexedTracks.map((t) => t.id!).toList();
    _playbackQueue = _isShuffleActive ? (List.of(ids)..shuffle()) : ids;
    if (_lastPlayedMusicId != null) {
      _currentQueueIndex = _playbackQueue.indexOf(_lastPlayedMusicId!);
      if (_currentQueueIndex == -1) {
        _lastPlayedMusicId = null;
        _currentQueueIndex = -1;
      }
    }
  }

  Future<void> loadIndexedTracks() async {
    try {
      _indexedTracks = await MusicDatabase.instance.readAllTracks();
      _indexedFileCount = _indexedTracks.length;
      if (_indexedFileCount > 0) {
        _indexingStatus = IndexingStatus.complete;
        _regenerateQueue();
      } else if (_rootDirectory != null) {
        _indexingStatus = IndexingStatus.idle;
      }
    } catch (e) {
      debugPrint('Erro ao carregar faixas: $e');
      _indexingStatus = IndexingStatus.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> startIndexing() async {
    if (_rootDirectory == null || _indexingStatus == IndexingStatus.scanning)
      return;
    _indexingStatus = IndexingStatus.scanning;
    _indexedTracks = [];
    _indexedFileCount = 0;
    notifyListeners();
    try {
      final paths = await compute(_scanDirectoryForPaths, _rootDirectory!);
      const batchSize = 50;
      final allTracks = <MusicTrack>[];
      for (int i = 0; i < paths.length; i += batchSize) {
        final batch = paths.sublist(i, (i + batchSize).clamp(0, paths.length));
        final batchTracks = await compute(_buildTracksFromPaths, batch);
        allTracks.addAll(batchTracks);
        _indexedFileCount = allTracks.length;
        notifyListeners();
      }
      _indexedTracks = await MusicDatabase.instance.insertTracks(allTracks);
      _indexedFileCount = _indexedTracks.length;
      _indexingStatus = IndexingStatus.complete;
      _lastScanDate = DateTime.now();
      await _saveLastScanDate(_lastScanDate!);
      _regenerateQueue();
      await _triggerMediaScan(_rootDirectory!);
    } catch (e) {
      _indexingStatus = IndexingStatus.error;
      debugPrint('Erro ao varrer: $e');
    } finally {
      notifyListeners();
    }
  }

  void playTrack(int musicId, {bool regenerateQueue = true}) {
    final idx = _indexedTracks.indexWhere((t) => t.id == musicId);
    if (idx == -1) return;
    if (_lastPlayedMusicId != musicId) {
      if (regenerateQueue) _regenerateQueue();
      _currentQueueIndex = _playbackQueue.indexOf(musicId);
      _lastPlayedMusicId = musicId;
      _saveLastPlayedMusicId(musicId);
      _lastSeekPositionMs = 0;
      _currentPositionMs = 0;
      _trackDurationMs = 0;
      _audioHandler?.customAction('loadTrack', {'path': currentTrackPath});
    }
    _isPlaying = true;
    notifyListeners();
    _audioHandler?.play();
  }

  void togglePlayPause() {
    if (_lastPlayedMusicId == null && _indexedTracks.isNotEmpty) {
      if (_playbackQueue.isNotEmpty) {
        final id = _playbackQueue.first;
        _lastPlayedMusicId = id;
        _currentQueueIndex = 0;
        _saveLastPlayedMusicId(id);
        _isPlaying = true;
        notifyListeners();
        _audioHandler?.customAction('loadTrack', {'path': currentTrackPath});
        _audioHandler?.play();
      }
      return;
    }
    if (_lastPlayedMusicId != null) {
      _isPlaying = !_isPlaying;
      notifyListeners();
      if (_isPlaying) {
        _audioHandler?.play();
      } else {
        _saveLastSeekPosition(_currentPositionMs);
        _audioHandler?.pause();
      }
    }
  }

  void playNextTrack({bool manualSkip = true}) {
    if (_playbackQueue.isEmpty) return;
    int next = _currentQueueIndex + 1;
    if (next >= _playbackQueue.length) {
      if (_repeatMode == 'All') {
        next = 0;
      } else {
        _audioHandler?.pause();
        return;
      }
    }
    _currentQueueIndex = next;
    playTrack(_playbackQueue[next], regenerateQueue: false);
  }

  void playPreviousTrack() {
    if (_playbackQueue.isEmpty) return;
    if (_currentPositionMs > 3000) {
      seekTo(0);
      return;
    }
    int prev = _currentQueueIndex - 1;
    if (prev < 0) {
      if (_repeatMode == 'All') {
        prev = _playbackQueue.length - 1;
      } else {
        seekTo(0);
        return;
      }
    }
    _currentQueueIndex = prev;
    playTrack(_playbackQueue[prev], regenerateQueue: false);
  }

  void toggleShuffle() {
    _isShuffleActive = !_isShuffleActive;
    _regenerateQueue();
    notifyListeners();
  }

  void toggleRepeatMode() {
    _repeatMode = switch (_repeatMode) {
      'Off' => 'All',
      'All' => 'One',
      _ => 'Off',
    };
    notifyListeners();
  }

  void trackDidFinish() {
    if (_lastPlayedMusicId == null || _playbackQueue.isEmpty) return;
    if (_repeatMode == 'One') {
      playTrack(_lastPlayedMusicId!);
      return;
    }
    playNextTrack(manualSkip: false);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('rootDirectory', _rootDirectory));
    properties.add(EnumProperty('indexingStatus', _indexingStatus));
    properties.add(IntProperty('indexedFileCount', _indexedFileCount));
  }
}
