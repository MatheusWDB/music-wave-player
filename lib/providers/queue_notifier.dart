import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'queue_notifier.g.dart';

const String _kQueueKey = 'queue_playbackQueue';
const String _kOriginalQueueKey = 'queue_originalQueue';
const String _kCurrentIndexKey = 'queue_currentIndex';

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
/// [QueueManager] — síncrono, mas com persistência própria em
/// SharedPreferences (ver [_persist]/[restoreOrRegenerate]), já que a
/// fila deixou de ser só reconstruída a partir das faixas indexadas a
/// cada carregamento do app.
@Riverpod(keepAlive: true)
class QueueNotifier extends _$QueueNotifier {
  @override
  QueueState build() => const QueueState();

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kQueueKey,
      state.playbackQueue.map((id) => id.toString()).toList(),
    );
    await prefs.setStringList(
      _kOriginalQueueKey,
      state.originalQueue.map((id) => id.toString()).toList(),
    );
    await prefs.setInt(_kCurrentIndexKey, state.currentQueueIndex);
  }

  /// Restaura a fila salva da sessão anterior, filtrando faixas que não
  /// existem mais na biblioteca (apagadas, etc.). Cai em [regenerate]
  /// (do zero, a partir de [tracks]) se não houver nada salvo ainda
  /// (primeira abertura) ou se sobrar vazio depois do filtro.
  Future<void> restoreOrRegenerate({
    required List<MusicTrack> tracks,
    required bool shuffleActive,
    required int? currentTrackId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final validIds = tracks.map((t) => t.id!).toSet();

    final savedQueue = prefs.getStringList(_kQueueKey);
    if (savedQueue != null && savedQueue.isNotEmpty) {
      final savedOriginal = prefs.getStringList(_kOriginalQueueKey);
      final restoredQueue = savedQueue
          .map(int.parse)
          .where(validIds.contains)
          .toList();
      final restoredOriginal = (savedOriginal ?? savedQueue)
          .map(int.parse)
          .where(validIds.contains)
          .toList();

      if (restoredQueue.isNotEmpty) {
        int currentIndex = currentTrackId != null
            ? restoredQueue.indexOf(currentTrackId)
            : -1;
        if (currentIndex < 0) currentIndex = 0;

        state = QueueState(
          playbackQueue: restoredQueue,
          originalQueue: restoredOriginal.isNotEmpty
              ? restoredOriginal
              : restoredQueue,
          currentQueueIndex: currentIndex,
        );
        unawaited(_persist());
        return;
      }
    }

    regenerate(
      tracks: tracks,
      shuffleActive: shuffleActive,
      currentTrackId: currentTrackId,
    );
  }

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
    unawaited(_persist());
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
    unawaited(_persist());
  }

  // ── Shuffle ───────────────────────────────────────────────────────────────

  /// Reembaralha a fila inteira, sem preservar nenhuma posição fixa —
  /// usado quando "Repetir tudo" + aleatório dá a volta na fila, pra não
  /// repetir a mesma sequência do ciclo anterior.
  void reshuffleAll() {
    if (state.playbackQueue.length <= 1) return;
    final shuffled = List.of(state.playbackQueue)..shuffle();
    state = state.copyWith(playbackQueue: shuffled);
    unawaited(_persist());
  }

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
    unawaited(_persist());
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
    unawaited(_persist());
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
    unawaited(_persist());
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
        unawaited(_persist());
        return QueueRemovePause();
      } else {
        final newIndex = index.clamp(0, queue.length - 1);
        state = state.copyWith(
          playbackQueue: queue,
          originalQueue: original,
          currentQueueIndex: newIndex,
        );
        unawaited(_persist());
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
      unawaited(_persist());
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
    unawaited(_persist());
  }

  /// Esvazia a fila por completo — sem nenhuma faixa atual, usado quando
  /// a fila chega ao fim sem repeat (nada mais a tocar).
  void clearAll() {
    state = const QueueState();
    unawaited(_persist());
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
    unawaited(_persist());
  }

  void addToEnd(List<int> ids) {
    if (ids.isEmpty) return;
    state = state.copyWith(
      playbackQueue: [...state.playbackQueue, ...ids],
      originalQueue: [...state.originalQueue, ...ids],
    );
    unawaited(_persist());
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
    unawaited(_persist());
  }

  void setCurrentIndex(int index) {
    state = state.copyWith(currentQueueIndex: index);
    unawaited(_persist());
  }

  void syncCurrentIndex(int? currentTrackId) {
    if (currentTrackId == null) return;
    state = state.copyWith(
      currentQueueIndex: state.playbackQueue.indexOf(currentTrackId),
    );
    unawaited(_persist());
  }
}
