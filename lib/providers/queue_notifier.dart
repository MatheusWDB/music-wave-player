import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'queue_notifier.g.dart';

const String _kQueueKey = 'queue_playbackQueue';
const String _kContextOrderKey = 'queue_contextOrder';
const String _kPlayedKey = 'queue_playedIds';
const String _kLibraryContextKey = 'queue_isLibraryContext';
const String _kCurrentIndexKey = 'queue_currentIndex';
// Chave antiga (quando a fila guardava só "original" e "ativa"): usada
// apenas como fallback de migração para a ordem original do contexto.
const String _kLegacyOriginalQueueKey = 'queue_originalQueue';

/// Estado imutável da fila de reprodução.
///
/// Modelo: uma única fila ativa ([playbackQueue]) lida como uma fita —
/// tudo antes de [currentQueueIndex] já passou, tudo depois ainda vai
/// tocar. A [contextOrder] guarda a ordem original do contexto (biblioteca,
/// playlist, álbum…), usada só pra recompor a ordem ao desligar o
/// aleatório. [playedIds] diz quais faixas **realmente tocaram** — tocar
/// uma faixa do meio da lista não faz as de cima virarem "histórico".
class QueueState {
  final List<int> playbackQueue;
  final List<int> contextOrder;
  final Set<int> playedIds;
  // true quando a fila veio da biblioteca inteira; só nesse caso faixas
  // novas indexadas depois entram na fila (numa playlist não fariam sentido).
  final bool isLibraryContext;
  final int currentQueueIndex;

  const QueueState({
    this.playbackQueue = const [],
    this.contextOrder = const [],
    this.playedIds = const {},
    this.isLibraryContext = true,
    this.currentQueueIndex = -1,
  });

  QueueState copyWith({
    List<int>? playbackQueue,
    List<int>? contextOrder,
    Set<int>? playedIds,
    bool? isLibraryContext,
    int? currentQueueIndex,
  }) {
    return QueueState(
      playbackQueue: playbackQueue ?? this.playbackQueue,
      contextOrder: contextOrder ?? this.contextOrder,
      playedIds: playedIds ?? this.playedIds,
      isLibraryContext: isLibraryContext ?? this.isLibraryContext,
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

/// A fila dividida em torno da faixa atual.
class _QueueSplit {
  /// Faixas que realmente tocaram antes da atual, na ordem da fila.
  final List<int> history;
  final int current;

  /// Tudo que ainda não tocou: o que vem depois da atual mais o que ficou
  /// antes dela sem nunca ter tocado.
  final List<int> rest;

  const _QueueSplit(this.history, this.current, this.rest);
}

/// Estado e operações da fila de reprodução, com persistência própria em
/// SharedPreferences (ver [_persist]/[restoreOrRegenerate]).
@Riverpod(keepAlive: true)
class QueueNotifier extends _$QueueNotifier {
  @override
  QueueState build() => const QueueState();

  // ── Persistência ──────────────────────────────────────────────────────────

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> asStrings(Iterable<int> ids) =>
        ids.map((id) => id.toString()).toList();
    await prefs.setStringList(_kQueueKey, asStrings(state.playbackQueue));
    await prefs.setStringList(_kContextOrderKey, asStrings(state.contextOrder));
    await prefs.setStringList(_kPlayedKey, asStrings(state.playedIds));
    await prefs.setBool(_kLibraryContextKey, state.isLibraryContext);
    await prefs.setInt(_kCurrentIndexKey, state.currentQueueIndex);
  }

  /// Restaura a fila salva da sessão anterior, filtrando faixas que não
  /// existem mais na biblioteca (apagadas, etc.). Cai em [regenerate]
  /// (do zero, a partir de [tracks]) se não houver nada salvo ainda
  /// (primeira abertura) ou se sobrar vazio depois do filtro.
  ///
  /// Devolve uma descrição curta do caminho tomado, só pra log de
  /// diagnóstico (quem chama registra).
  Future<String> restoreOrRegenerate({
    required List<MusicTrack> tracks,
    required bool shuffleActive,
    required int? currentTrackId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final validIds = tracks.map((t) => t.id!).toSet();

    List<int>? readIds(String key) =>
        prefs.getStringList(key)?.map(int.parse).toList();

    final savedQueue = readIds(_kQueueKey);
    if (savedQueue != null && savedQueue.isNotEmpty) {
      final queue = savedQueue.where(validIds.contains).toList();
      if (queue.isNotEmpty) {
        final savedContext =
            readIds(_kContextOrderKey) ??
            readIds(_kLegacyOriginalQueueKey) ??
            savedQueue;
        final contextOrder = savedContext.where(validIds.contains).toList();

        // Sem histórico salvo (dados de antes dessa versão): só a faixa
        // atual conta como tocada.
        final savedPlayed = readIds(_kPlayedKey);
        final played = <int>{
          ...?savedPlayed?.where(validIds.contains),
          if (currentTrackId != null) currentTrackId,
        };

        // Posição da faixa atual: o índice salvo, descontando as faixas
        // anteriores a ele que sumiram no filtro.
        final savedIndex = prefs.getInt(_kCurrentIndexKey) ?? -1;
        var index = savedIndex < 0
            ? -1
            : savedQueue.take(savedIndex).where(validIds.contains).length;
        if (currentTrackId != null &&
            (index < 0 ||
                index >= queue.length ||
                queue[index] != currentTrackId)) {
          index = queue.indexOf(currentTrackId);
        }
        if (index >= queue.length) index = queue.length - 1;

        state = QueueState(
          playbackQueue: queue,
          contextOrder: contextOrder.isEmpty ? queue : contextOrder,
          playedIds: played,
          isLibraryContext: prefs.getBool(_kLibraryContextKey) ?? true,
          currentQueueIndex: index,
        );
        unawaited(_persist());
        return 'fila RESTAURADA do disco: salvas=${savedQueue.length}, '
            'válidas=${queue.length}, índice=$index, '
            'histórico=${played.length}, aleatório=$shuffleActive';
      }
    }

    regenerate(
      tracks: tracks,
      shuffleActive: shuffleActive,
      currentTrackId: currentTrackId,
    );
    return 'fila REGENERADA do zero (nada salvo ou tudo inválido): '
        'faixas=${tracks.length}, aleatório=$shuffleActive';
  }

  // ── Criação da fila (novo contexto) ───────────────────────────────────────

  /// Nova fila a partir de [tracks] (por padrão, a biblioteca inteira), com
  /// [currentTrackId] como faixa atual. Com aleatório ligado, a faixa atual
  /// vai pro começo e o resto é embaralhado. Passe
  /// `isLibraryContext: false` para filas de artista, álbum ou playlist, que
  /// não devem receber faixas novas da biblioteca.
  void regenerate({
    required List<MusicTrack> tracks,
    required bool shuffleActive,
    required int? currentTrackId,
    bool isLibraryContext = true,
  }) {
    final ids = tracks.map((t) => t.id!).toList();

    List<int> queue;
    var index = -1;
    final played = <int>{};
    if (currentTrackId != null && ids.contains(currentTrackId)) {
      if (shuffleActive) {
        final rest = ids.where((id) => id != currentTrackId).toList()
          ..shuffle(Random());
        queue = [currentTrackId, ...rest];
        index = 0;
      } else {
        queue = ids;
        index = ids.indexOf(currentTrackId);
      }
      played.add(currentTrackId);
    } else {
      queue = shuffleActive ? (List.of(ids)..shuffle(Random())) : ids;
    }

    state = QueueState(
      playbackQueue: queue,
      contextOrder: List.of(ids),
      playedIds: played,
      isLibraryContext: isLibraryContext,
      currentQueueIndex: index,
    );
    unawaited(_persist());
  }

  /// Define uma nova fila ordenada, aplicando shuffle se necessário.
  /// Chamado ao tocar playlist, álbum ou artista.
  void setQueue({required List<int> orderedIds, required bool shuffleActive}) {
    if (orderedIds.isEmpty) {
      state = const QueueState();
      unawaited(_persist());
      return;
    }
    List<int> playbackQueue;
    if (shuffleActive && orderedIds.length > 1) {
      final first = orderedIds.first;
      final rest = orderedIds.sublist(1)..shuffle(Random());
      playbackQueue = [first, ...rest];
    } else {
      playbackQueue = List.of(orderedIds);
    }

    state = QueueState(
      playbackQueue: playbackQueue,
      contextOrder: List.of(orderedIds),
      playedIds: {playbackQueue.first},
      isLibraryContext: false,
      currentQueueIndex: 0,
    );
    unawaited(_persist());
  }

  /// Ajusta a fila às faixas atualmente visíveis da biblioteca (após
  /// indexação, ocultar/reexibir) **sem perder histórico nem a faixa
  /// atual**: faixas que saíram são removidas, e — só se a fila veio da
  /// biblioteca inteira — as realmente novas entram no fim.
  void syncWithLibrary({
    required List<MusicTrack> tracks,
    required bool shuffleActive,
    required int? currentTrackId,
  }) {
    if (state.playbackQueue.isEmpty) {
      regenerate(
        tracks: tracks,
        shuffleActive: shuffleActive,
        currentTrackId: currentTrackId,
      );
      return;
    }

    final ids = tracks.map((t) => t.id!).toList();
    final valid = ids.toSet();
    final oldQueue = state.playbackQueue;
    final oldIndex = state.currentQueueIndex;

    final queue = oldQueue.where(valid.contains).toList();
    // Faixas anteriores à atual que sobreviveram = novo índice dela (ou da
    // que passou a ocupar o lugar, se a atual foi removida).
    var index = oldIndex < 0
        ? -1
        : oldQueue.take(oldIndex).where(valid.contains).length;

    var contextOrder = state.contextOrder.where(valid.contains).toList();
    if (state.isLibraryContext) {
      final known = contextOrder.toSet();
      final fresh = ids.where((id) => !known.contains(id)).toList();
      contextOrder = [...contextOrder, ...fresh];
      final inQueue = queue.toSet();
      final toAdd = fresh.where((id) => !inQueue.contains(id)).toList();
      if (shuffleActive) toAdd.shuffle(Random());
      queue.addAll(toAdd);
    }
    if (index >= queue.length) index = queue.length - 1;

    state = state.copyWith(
      playbackQueue: queue,
      contextOrder: contextOrder,
      playedIds: state.playedIds.where(valid.contains).toSet(),
      currentQueueIndex: index,
    );
    unawaited(_persist());
  }

  // ── Shuffle ───────────────────────────────────────────────────────────────

  _QueueSplit? _split() {
    final queue = state.playbackQueue;
    final index = state.currentQueueIndex;
    if (index < 0 || index >= queue.length) return null;

    // Tudo antes da atual é histórico, tenha tocado ou não: ao começar de
    // uma faixa do meio, as de cima são "anteriores" e ficam fora do sorteio.
    return _QueueSplit(
      queue.sublist(0, index),
      queue[index],
      queue.sublist(index + 1),
    );
  }

  /// Liga o aleatório: o que vem antes da atual e a atual ficam no começo,
  /// na mesma ordem; só o que vem depois dela é embaralhado. Devolve uma
  /// descrição pro log de diagnóstico.
  String applyShuffle() {
    final split = _split();
    if (split == null) return 'aleatório LIGADO: fila sem faixa atual';
    final rest = List.of(split.rest)..shuffle(Random());
    state = state.copyWith(
      playbackQueue: [...split.history, split.current, ...rest],
      currentQueueIndex: split.history.length,
    );
    unawaited(_persist());
    return 'aleatório LIGADO: histórico=${split.history.length}, '
        'embaralhadas=${rest.length}';
  }

  /// Desliga o aleatório: o que vem antes da atual e a atual ficam no
  /// começo, na mesma ordem; o resto volta pra ordem original do contexto.
  /// Faixas que não são do contexto (adicionadas à mão) vão pro fim, na
  /// ordem atual.
  String removeShuffle() {
    final split = _split();
    if (split == null) return 'aleatório DESLIGADO: fila sem faixa atual';

    final position = <int, int>{};
    for (var i = 0; i < state.contextOrder.length; i++) {
      position.putIfAbsent(state.contextOrder[i], () => i);
    }
    final unknownBase = state.contextOrder.length;
    final keyed = [
      for (var i = 0; i < split.rest.length; i++)
        [position[split.rest[i]] ?? unknownBase + i, split.rest[i]],
    ]..sort((a, b) => a[0].compareTo(b[0]));

    state = state.copyWith(
      playbackQueue: [
        ...split.history,
        split.current,
        ...keyed.map((e) => e[1]),
      ],
      currentQueueIndex: split.history.length,
    );
    unawaited(_persist());
    return 'aleatório DESLIGADO: histórico=${split.history.length}, '
        'em ordem original=${keyed.length}';
  }

  /// Começa uma nova rodada quando a fila dá a volta (repetir tudo): zera
  /// o histórico e remonta a fila — embaralhada com aleatório, ou na
  /// ordem original pura do contexto sem ele. Com aleatório, evita que a
  /// faixa que acabou de tocar abra a nova rodada ([avoidFirstId]).
  /// Deixa o índice em -1: quem chama avança pro índice 0 em seguida.
  void restartCycle({required bool shuffle, int? avoidFirstId}) {
    final inQueue = state.playbackQueue.toSet();
    final contextSet = state.contextOrder.toSet();
    final base = state.contextOrder.where(inQueue.contains).toSet().toList();
    final extras = state.playbackQueue
        .where((id) => !contextSet.contains(id))
        .toList();
    final queue = [...base, ...extras];

    if (shuffle && queue.length > 1) {
      final rng = Random();
      queue.shuffle(rng);
      if (avoidFirstId != null && queue.first == avoidFirstId) {
        final swapWith = 1 + rng.nextInt(queue.length - 1);
        final tmp = queue[0];
        queue[0] = queue[swapWith];
        queue[swapWith] = tmp;
      }
    }

    state = state.copyWith(
      playbackQueue: queue,
      playedIds: <int>{},
      currentQueueIndex: -1,
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
    queue.removeAt(index);

    if (removingCurrent) {
      if (queue.isEmpty) {
        state = state.copyWith(playbackQueue: queue, currentQueueIndex: -1);
        unawaited(_persist());
        return QueueRemovePause();
      } else {
        final newIndex = index.clamp(0, queue.length - 1);
        state = state.copyWith(
          playbackQueue: queue,
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
      contextOrder: [currentTrackId],
      playedIds: {currentTrackId},
      isLibraryContext: false,
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
    for (int i = 0; i < ids.length; i++) {
      queue.insert(insertAt + i, ids[i]);
    }
    state = state.copyWith(playbackQueue: queue);
    unawaited(_persist());
  }

  void addToEnd(List<int> ids) {
    if (ids.isEmpty) return;
    state = state.copyWith(playbackQueue: [...state.playbackQueue, ...ids]);
    unawaited(_persist());
  }

  void removeTracksById(List<int> ids) {
    state = state.copyWith(
      playbackQueue: state.playbackQueue
          .where((id) => !ids.contains(id))
          .toList(),
    );
    unawaited(_persist());
  }

  /// Move a cabeça da fila pro [index] e marca a faixa como tocada.
  void setCurrentIndex(int index) {
    final queue = state.playbackQueue;
    final Set<int> played = index >= 0 && index < queue.length
        ? {...state.playedIds, queue[index]}
        : state.playedIds;
    state = state.copyWith(currentQueueIndex: index, playedIds: played);
    unawaited(_persist());
  }

  void syncCurrentIndex(int? currentTrackId) {
    if (currentTrackId == null) return;
    final queue = state.playbackQueue;
    final current = state.currentQueueIndex;
    // Já está apontando pra essa faixa (inclusive se ela aparecer duas
    // vezes na fila) — não puxa o índice pra primeira ocorrência.
    final index =
        current >= 0 &&
            current < queue.length &&
            queue[current] == currentTrackId
        ? current
        : queue.indexOf(currentTrackId);
    state = state.copyWith(
      currentQueueIndex: index,
      playedIds: {...state.playedIds, currentTrackId},
    );
    unawaited(_persist());
  }
}
