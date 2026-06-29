import 'dart:math';

import 'package:music_wave_player/models/music_track.dart';

/// Estado e operações da fila de reprodução.
///
/// Mantém [playbackQueue] e [originalQueue] sincronizados e delega
/// ações de reprodução via callbacks — sem acoplamento direto ao [Configuration].
/// No Riverpod, esta classe vira um [Notifier] com estado imutável.
class QueueManager {
  List<int> _playbackQueue = [];
  List<int> _originalQueue = [];
  int _currentQueueIndex = -1;

  List<int> get playbackQueue => List.unmodifiable(_playbackQueue);
  List<int> get originalQueue => List.unmodifiable(_originalQueue);
  int get currentQueueIndex => _currentQueueIndex;

  // ── Inicialização ─────────────────────────────────────────────────────────

  /// Reconstrói a fila completa a partir das faixas indexadas.
  /// Chamado após indexação, hide/unhide e carregamento inicial.
  void regenerate({
    required List<MusicTrack> tracks,
    required bool shuffleActive,
    required int? currentTrackId,
    required void Function(int? clearedTrackId) onCurrentCleared,
  }) {
    final ids = tracks.map((t) => t.id!).toList();
    _originalQueue = List.of(ids);
    _playbackQueue = shuffleActive ? (List.of(ids)..shuffle()) : ids;

    if (currentTrackId != null) {
      _currentQueueIndex = _playbackQueue.indexOf(currentTrackId);
      if (_currentQueueIndex == -1) {
        onCurrentCleared(null);
      }
    }
  }

  /// Define uma nova fila ordenada, aplicando shuffle se necessário.
  /// Chamado ao tocar playlist, álbum ou artista.
  void setQueue({required List<int> orderedIds, required bool shuffleActive}) {
    _originalQueue = List.of(orderedIds);
    _currentQueueIndex = 0;
    if (shuffleActive && orderedIds.length > 1) {
      final first = orderedIds.first;
      final rest = orderedIds.sublist(1)..shuffle();
      _playbackQueue = [first, ...rest];
    } else {
      _playbackQueue = List.of(orderedIds);
    }
  }

  // ── Shuffle ───────────────────────────────────────────────────────────────

  void applyShuffle(int currentQueueIndex) {
    if (_playbackQueue.length <= 1) return;
    _currentQueueIndex = currentQueueIndex;
    _originalQueue = List.of(_playbackQueue);
    final rng = Random();
    final before = _playbackQueue.sublist(0, _currentQueueIndex)..shuffle(rng);
    final current = _playbackQueue[_currentQueueIndex];
    final after = _playbackQueue.sublist(_currentQueueIndex + 1)..shuffle(rng);
    _playbackQueue = [...before, current, ...after];
  }

  void restoreOriginal(int? currentTrackId) {
    if (_originalQueue.isEmpty) return;
    _playbackQueue = List.of(_originalQueue);
    if (currentTrackId != null) {
      _currentQueueIndex = _playbackQueue.indexOf(currentTrackId);
    }
  }

  // ── Operações de fila ─────────────────────────────────────────────────────

  void reorder(int oldIndex, int newIndex, int? currentTrackId) {
    if (oldIndex < newIndex) newIndex -= 1;
    final id = _playbackQueue.removeAt(oldIndex);
    _playbackQueue.insert(newIndex, id);
    if (currentTrackId != null) {
      _currentQueueIndex = _playbackQueue.indexOf(currentTrackId);
    }
    _originalQueue = List.of(_playbackQueue);
  }

  /// Remove item da fila. Retorna ação necessária ao chamador.
  QueueRemoveResult remove({required int index, required int? currentTrackId}) {
    if (index < 0 || index >= _playbackQueue.length) {
      return QueueRemoveNone();
    }

    final removingCurrent = index == _currentQueueIndex;
    final removedId = _playbackQueue.removeAt(index);
    _originalQueue.remove(removedId);

    if (removingCurrent) {
      if (_playbackQueue.isEmpty) {
        _currentQueueIndex = -1;
        return QueueRemovePause();
      } else {
        _currentQueueIndex = index.clamp(0, _playbackQueue.length - 1);
        return QueueRemovePlayTrack(_playbackQueue[_currentQueueIndex]);
      }
    } else {
      if (currentTrackId != null) {
        _currentQueueIndex = _playbackQueue.indexOf(currentTrackId);
      }
      return QueueRemoveNone();
    }
  }

  void clear(int? currentTrackId) {
    if (currentTrackId == null) return;
    _playbackQueue = [currentTrackId];
    _originalQueue = [currentTrackId];
    _currentQueueIndex = 0;
  }

  void insertAfterCurrent(List<int> ids) {
    if (ids.isEmpty) return;
    final insertAt = _currentQueueIndex + 1;
    for (int i = 0; i < ids.length; i++) {
      _playbackQueue.insert(insertAt + i, ids[i]);
      _originalQueue.insert(insertAt + i, ids[i]);
    }
  }

  void addToEnd(List<int> ids) {
    if (ids.isEmpty) return;
    _playbackQueue.addAll(ids);
    _originalQueue.addAll(ids);
  }

  void removeTracksById(List<int> ids) {
    for (int i = _playbackQueue.length - 1; i >= 0; i--) {
      if (ids.contains(_playbackQueue[i])) {
        _playbackQueue.removeAt(i);
      }
    }
    _originalQueue.removeWhere((id) => ids.contains(id));
  }

  void setCurrentIndex(int index) => _currentQueueIndex = index;

  void syncCurrentIndex(int? currentTrackId) {
    if (currentTrackId == null) return;
    _currentQueueIndex = _playbackQueue.indexOf(currentTrackId);
  }
}

/// Resultado de uma operação de remoção da fila.
/// Evita que [QueueManager] chame diretamente métodos de reprodução.
sealed class QueueRemoveResult {}

class QueueRemoveNone extends QueueRemoveResult {}

class QueueRemovePause extends QueueRemoveResult {}

class QueueRemovePlayTrack extends QueueRemoveResult {
  final int trackId;
  QueueRemovePlayTrack(this.trackId);
}
