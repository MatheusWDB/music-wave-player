import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kRootDirectoryKey = 'rootDirectoryPath';

enum IndexingStatus { idle, scanning, complete, error }

class Configuration with ChangeNotifier, DiagnosticableTreeMixin {
  String? _rootDirectory;
  DateTime? _lastScanDate;
  IndexingStatus _indexingStatus = IndexingStatus.idle;
  int? _lastPlayedMusicId;
  int _lastSeekPositionMs;
  bool _isShuffleActive;
  String _repeatMode;
  DateTime? _sleepTimerEnd;
  bool _timerIsPaused;

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

    return Configuration._(
      savedRootDirectory,
      null,
      null,
      0,
      false,
      'Off',
      null,
      false,
    );
  }

  String? get rootDirectory => _rootDirectory;
  DateTime? get lastScanDate => _lastScanDate;
  IndexingStatus get indexingStatus => _indexingStatus;
  int? get lastPlayedMusicId => _lastPlayedMusicId;
  int get lastSeekPositionMs => _lastSeekPositionMs;
  bool get isShuffleActive => _isShuffleActive;
  String get repeatMode => _repeatMode;
  DateTime? get sleepTimerEnd => _sleepTimerEnd;
  bool get timerIsPaused => _timerIsPaused;

  set rootDirectory(String path) {
    if (_rootDirectory == path) return;

    _rootDirectory = path;
    _indexingStatus = IndexingStatus.idle;
    notifyListeners();
    _saveRootDirectory(path);
  }

  Future<void> _saveRootDirectory(String path) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRootDirectoryKey, path);
  }

  void startIndexing() {
    if (_rootDirectory == null || _indexingStatus == IndexingStatus.scanning)
      return;

    _indexingStatus = IndexingStatus.scanning;
    notifyListeners();

    // ⚠️ Lógica real de varredura (assíncrona):
    // 1. Usar um pacote como `path_provider` e `dart:io` para ler arquivos.
    // 2. Filtrar por extensões válidas (RN02).
    // 3. Extrair metadados.
    // 4. Inserir no DB.

    // Simulação:
    Future.delayed(const Duration(seconds: 3), () {
      _indexingStatus = IndexingStatus.complete;
      _lastScanDate = DateTime.now();
      notifyListeners();
      // ⚠️ Futura implementação: Salvar a mudança no DB/Prefs
    });
  }

  Future<void> saveConfiguration() async {}

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('rootDirectory', _rootDirectory));
    properties.add(EnumProperty('indexingStatus', _indexingStatus));
    properties.add(
      DiagnosticsProperty<DateTime>('lastScanDate', _lastScanDate),
    );
    // ... adicione as outras propriedades importantes
  }
}
