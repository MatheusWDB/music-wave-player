import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kRootDirectoryKey = 'rootDirectoryPath';
const String _kLastScanDateKey = 'lastScanDate';

enum IndexingStatus { idle, scanning, complete, error }

class Configuration with ChangeNotifier, DiagnosticableTreeMixin {
  String? _rootDirectory;
  DateTime? _lastScanDate;
  IndexingStatus _indexingStatus = IndexingStatus.idle;
  List<MusicTrack> _indexedTracks = [];
  int _indexedFileCount = 0;
  int? _lastPlayedMusicId;
  int _lastSeekPositionMs;
  bool _isShuffleActive;
  String _repeatMode;
  DateTime? _sleepTimerEnd;
  bool _timerIsPaused;
  bool _isPlaying = false;

  Configuration._(
    this._rootDirectory,
    this._lastScanDate,
    this._lastPlayedMusicId,
    this._lastSeekPositionMs,
    this._isShuffleActive,
    this._repeatMode,
    this._sleepTimerEnd,
    this._timerIsPaused,
  );

  static Future<Configuration> loadFromStorage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? savedRootDirectory = prefs.getString(_kRootDirectoryKey);
    final int? savedLastScanTimestamp = prefs.getInt(_kLastScanDateKey);
    final DateTime? savedLastScanDate = savedLastScanTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(savedLastScanTimestamp)
        : null;

    final config = Configuration._(
      savedRootDirectory,
      savedLastScanDate,
      null,
      0,
      false,
      'Off',
      null,
      false,
    );

    await config.loadIndexedTracks();

    return config;
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
  DateTime? get sleepTimerEnd => _sleepTimerEnd;
  bool get timerIsPaused => _timerIsPaused;
  bool get isPlaying => _isPlaying;

  set rootDirectory(String path) {
    if (_rootDirectory == path) return;

    _rootDirectory = path;
    _indexingStatus = IndexingStatus.idle;
    notifyListeners();
    _saveRootDirectory(path);
  }

  Future<void> _saveLastScanDate(DateTime date) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastScanDateKey, date.millisecondsSinceEpoch);
  }

  Future<void> _saveRootDirectory(String path) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRootDirectoryKey, path);
  }

  Future<void> loadIndexedTracks() async {
    try {
      _indexedTracks = await MusicDatabase.instance.readAllTracks();
      _indexedFileCount = _indexedTracks.length;
      if (_indexedFileCount > 0) {
        _indexingStatus = IndexingStatus.complete;
      }
    } catch (e) {
      debugPrint("Erro ao carregar faixas salvas: $e");
      _indexingStatus = IndexingStatus.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _saveIndexedTracks() async {
    try {
      _indexedTracks = await MusicDatabase.instance.insertTracks(
        _indexedTracks,
      );
      debugPrint(
        "Foram salvas ${_indexedTracks.length} faixas no banco de dados.",
      );
    } catch (e) {
      debugPrint("Erro ao salvar faixas no banco de dados: $e");
    }
  }

  Future<void> startIndexing() async {
    if (_rootDirectory == null || _indexingStatus == IndexingStatus.scanning) {
      return;
    }

    _indexingStatus = IndexingStatus.scanning;
    _indexedTracks = [];
    _indexedFileCount = 0;
    notifyListeners();

    try {
      final rootDir = Directory(_rootDirectory!);

      if (!await rootDir.exists()) {
        _indexingStatus = IndexingStatus.error;
        notifyListeners();
        debugPrint(
          "Erro: Diretório raiz não existe ou acesso negado. Caminho: ${_rootDirectory!}",
        );
        return;
      }

      debugPrint("Iniciando varredura em: ${_rootDirectory!}");

      await _scanDirectory(rootDir);

      _indexingStatus = IndexingStatus.complete;
      _lastScanDate = DateTime.now();

      await _saveIndexedTracks();
      await _saveLastScanDate(_lastScanDate!);
    } catch (e) {
      _indexingStatus = IndexingStatus.error;
      debugPrint("Erro ao varrer o diretório: $e");
    } finally {
      notifyListeners();
    }
  }

  Future<void> _scanDirectory(Directory dir) async {
    final Stream<FileSystemEntity> fileSystemEntities = dir.list(
      recursive: true,
      followLinks: false,
    );

    await for (final entity in fileSystemEntities) {
      if (entity is File) {
        if (MusicTrack.isSupported(entity.path)) {
          // --- SIMULAÇÃO DA EXTRAÇÃO DE METADADOS ---
          String fileName = entity.path.split(Platform.pathSeparator).last;

          final MusicTrack track = MusicTrack(
            path: entity.path,
            title: fileName.split(".")[0],
            artist: 'Artista Desconhecido',
            album: 'Álbum Desconhecido',
          );

          _indexedTracks.add(track);
          _indexedFileCount = _indexedTracks.length;

          if (_indexedFileCount % 10 == 0) {
            notifyListeners();
          }
        }
      }
    }
  }

  
  void playTrack(int? musicId) {
    if (_lastPlayedMusicId != musicId) {
      _lastPlayedMusicId = musicId;
      _lastSeekPositionMs = 0; 
    }
    _isPlaying = true;
    notifyListeners();
    // Em um app real, você chamaria o player de áudio aqui para carregar e iniciar a faixa.
  }

  
  void togglePlayPause() {
    if (_lastPlayedMusicId == null && _indexedTracks.isNotEmpty) {
      playTrack(_indexedTracks.first.id);
      return;
    }

    if (_lastPlayedMusicId != null) {
      _isPlaying = !_isPlaying;
      notifyListeners();

      // Em um app real:
      // if (_isPlaying) { player.resume(); } else { player.pause(); }
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('rootDirectory', _rootDirectory));
    properties.add(EnumProperty('indexingStatus', _indexingStatus));
    properties.add(
      DiagnosticsProperty<DateTime>('lastScanDate', _lastScanDate),
    );
    properties.add(IntProperty('indexedFileCount', _indexedFileCount));
  }
}
