import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:music_wave_player/models/music_track.dart';

part 'queue_notifier.g.dart';

/// Estado imutável da fila de reprodução.
class QueueState {
  final List<int> playbackQueue;
  final List<int> originalQueue;
  final int currentQueueIndex;

  const QueueState({
    this.playbackQueue = const [],
    this.originalQueue = const [],
    this.currentQueueIndex = -1,
  });

  QueueState copyWith({
    List<int>? playbackQueue,
    List<int>? originalQueue,
    int? currentQueueIndex,
  }) {
    return QueueState(
      playbackQueue: playbackQueue ?? this.playbackQueue,
      originalQueue: originalQueue ?? this.originalQueue,
      currentQueueIndex: currentQueueIndex ?? this.currentQueueIndex,
    );
  }
}

/// Resultado de uma operação de remoção da fila — evita que o Notifier
/// precise chamar diretamente métodos de reprodução de outro Notifier.
sealed class QueueRemoveResult {}

class QueueRemoveNone extends QueueRemoveResult {}

class QueueRemovePause extends QueueRemoveResult {}

class QueueRemovePlayTrack extends QueueRemoveResult {
  final int trackId;
  QueueRemovePlayTrack(this.trackId);
}

/// Estado e operações da fila de reprodução. Substitui o antigo
/// [QueueManager] — síncrono e sem persistência, já que a fila é
/// reconstruída a partir das faixas indexadas a cada carregamento do app.
@Riverpod(keepAlive: true)
class QueueNotifier extends _$QueueNotifier {
  @override
  QueueState build() => const QueueState();

  /// Reconstrói a fila completa a partir das faixas indexadas. Chamado
  /// após indexação, hide/unhide e carregamento inicial.
  void regenerate({
    required List<MusicTrack> tracks,
    required bool shuffleActive,
    required int? currentTrackId,
  }) {
    final ids = tracks.map((t) => t.id!).toList();
    final playbackQueue = shuffleActive ? (List.of(ids)..shuffle()) : ids;

    int currentIndex = state.currentQueueIndex;
    if (currentTrackId != null) {
      currentIndex = playbackQueue.indexOf(currentTrackId);
    }

    state = QueueState(
      playbackQueue: playbackQueue,
      originalQueue: List.of(ids),
      currentQueueIndex: currentIndex,
    );
  }

  /// Define uma nova fila ordenada, aplicando shuffle se necessário.
  /// Chamado ao tocar playlist, álbum ou artista.
  void setQueue({required List<int> orderedIds, required bool shuffleActive}) {
    List<int> playbackQueue;
    if (shuffleActive && orderedIds.length > 1) {
      final first = orderedIds.first;
      final rest = orderedIds.sublist(1)..shuffle();
      playbackQueue = [first, ...rest];
    } else {
      playbackQueue = List.of(orderedIds);
    }

    state = QueueState(
      playbackQueue: playbackQueue,
      originalQueue: List.of(orderedIds),
      currentQueueIndex: 0,
    );
  }

  // ── Shuffle ───────────────────────────────────────────────────────────────

  void applyShuffle(int currentQueueIndex) {
    if (state.playbackQueue.length <= 1) return;
    final original = List.of(state.playbackQueue);
    final rng = Random();
    final before = state.playbackQueue.sublist(0, currentQueueIndex)
      ..shuffle(rng);
    final current = state.playbackQueue[currentQueueIndex];
    final after = state.playbackQueue.sublist(currentQueueIndex + 1)
      ..shuffle(rng);

    state = state.copyWith(
      playbackQueue: [...before, current, ...after],
      originalQueue: original,
      currentQueueIndex: currentQueueIndex,
    );
  }

  void restoreOriginal(int? currentTrackId) {
    if (state.originalQueue.isEmpty) return;
    final playbackQueue = List.of(state.originalQueue);
    int currentIndex = state.currentQueueIndex;
    if (currentTrackId != null) {
      currentIndex = playbackQueue.indexOf(currentTrackId);
    }
    state = state.copyWith(
      playbackQueue: playbackQueue,
      currentQueueIndex: currentIndex,
    );
  }

  // ── Operações de fila ─────────────────────────────────────────────────────

  void reorder(int oldIndex, int newIndex, int? currentTrackId) {
    if (oldIndex < newIndex) newIndex -= 1;
    final queue = List.of(state.playbackQueue);
    final id = queue.removeAt(oldIndex);
    queue.insert(newIndex, id);

    int currentIndex = state.currentQueueIndex;
    if (currentTrackId != null) {
      currentIndex = queue.indexOf(currentTrackId);
    }

    state = state.copyWith(
      playbackQueue: queue,
      originalQueue: List.of(queue),
      currentQueueIndex: currentIndex,
    );
  }

  /// Remove item da fila. Retorna a ação necessária ao chamador.
  QueueRemoveResult remove({required int index, required int? currentTrackId}) {
    if (index < 0 || index >= state.playbackQueue.length) {
      return QueueRemoveNone();
    }

    final removingCurrent = index == state.currentQueueIndex;
    final queue = List.of(state.playbackQueue);
    final removedId = queue.removeAt(index);
    final original = List.of(state.originalQueue)..remove(removedId);

    if (removingCurrent) {
      if (queue.isEmpty) {
        state = state.copyWith(
          playbackQueue: queue,
          originalQueue: original,
          currentQueueIndex: -1,
        );
        return QueueRemovePause();
      } else {
        final newIndex = index.clamp(0, queue.length - 1);
        state = state.copyWith(
          playbackQueue: queue,
          originalQueue: original,
          currentQueueIndex: newIndex,
        );
        return QueueRemovePlayTrack(queue[newIndex]);
      }
    } else {
      int currentIndex = state.currentQueueIndex;
      if (currentTrackId != null) {
        currentIndex = queue.indexOf(currentTrackId);
      }
      state = state.copyWith(
        playbackQueue: queue,
        originalQueue: original,
        currentQueueIndex: currentIndex,
      );
      return QueueRemoveNone();
    }
  }

  void clear(int? currentTrackId) {
    if (currentTrackId == null) return;
    state = QueueState(
      playbackQueue: [currentTrackId],
      originalQueue: [currentTrackId],
      currentQueueIndex: 0,
    );
  }

  void insertAfterCurrent(List<int> ids) {
    if (ids.isEmpty) return;
    final insertAt = state.currentQueueIndex + 1;
    final queue = List.of(state.playbackQueue);
    final original = List.of(state.originalQueue);
    for (int i = 0; i < ids.length; i++) {
      queue.insert(insertAt + i, ids[i]);
      original.insert(insertAt + i, ids[i]);
    }
    state = state.copyWith(playbackQueue: queue, originalQueue: original);
  }

  void addToEnd(List<int> ids) {
    if (ids.isEmpty) return;
    state = state.copyWith(
      playbackQueue: [...state.playbackQueue, ...ids],
      originalQueue: [...state.originalQueue, ...ids],
    );
  }

  void removeTracksById(List<int> ids) {
    state = state.copyWith(
      playbackQueue: state.playbackQueue
          .where((id) => !ids.contains(id))
          .toList(),
      originalQueue: state.originalQueue
          .where((id) => !ids.contains(id))
          .toList(),
    );
  }

  void setCurrentIndex(int index) {
    state = state.copyWith(currentQueueIndex: index);
  }

  void syncCurrentIndex(int? currentTrackId) {
    if (currentTrackId == null) return;
    state = state.copyWith(
      currentQueueIndex: state.playbackQueue.indexOf(currentTrackId),
    );
  }
}
