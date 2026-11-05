import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/queue_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

MusicTrack _track(int id) => MusicTrack(
  id: id,
  path: '/music/$id.mp3',
  title: 'Faixa $id',
  artist: 'Artista',
  album: 'Álbum',
);

List<MusicTrack> _library(int count) =>
    List.generate(count, (i) => _track(i + 1));

ProviderContainer _newContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

// O notifier grava as preferências sem await; uma volta no event loop
// basta para as gravações terminarem antes de "reabrir o app".
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('B5 - restoreOrRegenerate (reabrir o app)', () {
    test('restaura fila, índice e histórico com aleatório ligado', () async {
      final library = _library(20);
      final first = _newContainer();
      final queue = first.read(queueNotifierProvider.notifier);
      queue.regenerate(tracks: library, shuffleActive: true, currentTrackId: 5);
      queue
        ..setCurrentIndex(1)
        ..setCurrentIndex(2)
        ..setCurrentIndex(3);
      await _settle();
      final saved = first.read(queueNotifierProvider);

      final second = _newContainer();
      final result = await second
          .read(queueNotifierProvider.notifier)
          .restoreOrRegenerate(
            tracks: library,
            shuffleActive: true,
            currentTrackId: saved.playbackQueue[3],
          );
      final restored = second.read(queueNotifierProvider);

      expect(result, contains('RESTAURADA'));
      expect(restored.playbackQueue, saved.playbackQueue);
      expect(restored.currentQueueIndex, 3);
      expect(restored.playedIds, saved.playedIds);
      expect(restored.playedIds.length, 4);
    });

    test('descarta faixas que saíram da biblioteca e mantém a atual', () async {
      final library = _library(20);
      final first = _newContainer();
      final queue = first.read(queueNotifierProvider.notifier);
      queue.regenerate(tracks: library, shuffleActive: true, currentTrackId: 5);
      queue
        ..setCurrentIndex(1)
        ..setCurrentIndex(2)
        ..setCurrentIndex(3);
      await _settle();
      final saved = first.read(queueNotifierProvider);
      final currentId = saved.playbackQueue[3];
      final removed = saved.playbackQueue.take(2).toSet();
      final reduced = library.where((t) => !removed.contains(t.id)).toList();

      final second = _newContainer();
      await second
          .read(queueNotifierProvider.notifier)
          .restoreOrRegenerate(
            tracks: reduced,
            shuffleActive: true,
            currentTrackId: currentId,
          );
      final restored = second.read(queueNotifierProvider);

      expect(restored.playbackQueue, saved.playbackQueue.skip(2).toList());
      expect(restored.currentQueueIndex, 1);
      expect(restored.playbackQueue[restored.currentQueueIndex], currentId);
      expect(restored.playedIds.intersection(removed), isEmpty);
    });

    test('sem nada salvo, regenera a fila do zero', () async {
      final library = _library(10);
      final container = _newContainer();

      final result = await container
          .read(queueNotifierProvider.notifier)
          .restoreOrRegenerate(
            tracks: library,
            shuffleActive: false,
            currentTrackId: null,
          );
      final state = container.read(queueNotifierProvider);

      expect(result, contains('REGENERADA'));
      expect(state.playbackQueue, library.map((t) => t.id).toList());
      expect(state.currentQueueIndex, -1);
      expect(state.playedIds, isEmpty);
    });

    test(
      'fila esvaziada ao fim sem repeat não volta com faixa atual',
      () async {
        final library = _library(10);
        final first = _newContainer();
        final queue = first.read(queueNotifierProvider.notifier);
        queue.regenerate(
          tracks: library,
          shuffleActive: false,
          currentTrackId: 3,
        );
        queue.clearAll();
        await _settle();

        // Sem lastPlayedMusicId (limpo ao fim da fila), currentTrackId é nulo.
        final second = _newContainer();
        await second
            .read(queueNotifierProvider.notifier)
            .restoreOrRegenerate(
              tracks: library,
              shuffleActive: false,
              currentTrackId: null,
            );
        final state = second.read(queueNotifierProvider);

        expect(state.currentQueueIndex, -1);
        expect(state.playedIds, isEmpty);
      },
    );
  });

  group('B6 - restartCycle (repetir tudo)', () {
    late ProviderContainer container;
    late QueueNotifier queue;
    final library = _library(10);
    final ids = library.map((t) => t.id!).toList();

    setUp(() {
      container = _newContainer();
      queue = container.read(queueNotifierProvider.notifier);
      queue.regenerate(tracks: library, shuffleActive: true, currentTrackId: 7);
    });

    test('com aleatório, a nova rodada nunca abre com a última faixa', () {
      // A fila é embaralhada ao acaso, então repete para pegar o caso de
      // a última faixa cair na primeira posição.
      for (var i = 0; i < 300; i++) {
        queue.restartCycle(shuffle: true, avoidFirstId: 7);
        expect(
          container.read(queueNotifierProvider).playbackQueue.first,
          isNot(7),
        );
      }
    });

    test('zera histórico e índice e mantém todas as faixas uma vez', () {
      queue.restartCycle(shuffle: true, avoidFirstId: 7);
      final state = container.read(queueNotifierProvider);

      expect(state.playedIds, isEmpty);
      expect(state.currentQueueIndex, -1);
      expect([...state.playbackQueue]..sort(), ids);
    });

    test('sem aleatório, volta para a ordem original do contexto', () {
      queue.restartCycle(shuffle: false);

      expect(container.read(queueNotifierProvider).playbackQueue, ids);
    });

    test('mantém no fim as faixas adicionadas à mão', () {
      queue.addToEnd([99]);
      queue.restartCycle(shuffle: false);
      final state = container.read(queueNotifierProvider);

      expect(state.playbackQueue, [...ids, 99]);
    });
  });

  group('Aleatório - começando de uma faixa do meio', () {
    late ProviderContainer container;
    late QueueNotifier queue;
    final library = _library(10);

    setUp(() {
      container = _newContainer();
      queue = container.read(queueNotifierProvider.notifier);
      queue.regenerate(
        tracks: library,
        shuffleActive: false,
        currentTrackId: 5,
      );
    });

    test('ligar o aleatório não sorteia as faixas de cima', () {
      queue.applyShuffle();
      final state = container.read(queueNotifierProvider);

      expect(state.playbackQueue.take(5), [1, 2, 3, 4, 5]);
      expect(state.currentQueueIndex, 4);
      expect(state.playbackQueue.skip(5).toSet(), {6, 7, 8, 9, 10});
    });

    test('desligar o aleatório continua na ordem depois da atual', () {
      queue.applyShuffle();
      queue.removeShuffle();
      final state = container.read(queueNotifierProvider);

      expect(state.playbackQueue, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(state.currentQueueIndex, 4);
    });
  });

  group('B7 - syncWithLibrary (reindexar com a fila ativa)', () {
    late ProviderContainer container;
    late QueueNotifier queue;
    final library = _library(10);

    setUp(() {
      container = _newContainer();
      queue = container.read(queueNotifierProvider.notifier);
    });

    test('preserva histórico e faixa atual ao entrarem faixas novas', () {
      queue.regenerate(
        tracks: library,
        shuffleActive: false,
        currentTrackId: 3,
      );
      // Tocam as faixas dos índices 3 e 4 (ids 4 e 5); a atual é a de id 5.
      queue
        ..setCurrentIndex(3)
        ..setCurrentIndex(4);
      final before = container.read(queueNotifierProvider);

      queue.syncWithLibrary(
        tracks: [...library, _track(11), _track(12)],
        shuffleActive: false,
        currentTrackId: 5,
      );
      final after = container.read(queueNotifierProvider);

      expect(after.playbackQueue, [...before.playbackQueue, 11, 12]);
      expect(after.currentQueueIndex, before.currentQueueIndex);
      expect(after.playbackQueue[after.currentQueueIndex], 5);
      expect(after.playedIds, before.playedIds);
    });

    test('faixas novas entram no fim sem mexer na ordem existente', () {
      queue.regenerate(tracks: library, shuffleActive: true, currentTrackId: 2);
      final before = container.read(queueNotifierProvider);

      queue.syncWithLibrary(
        tracks: [...library, _track(11), _track(12)],
        shuffleActive: true,
        currentTrackId: 2,
      );
      final after = container.read(queueNotifierProvider);

      expect(
        after.playbackQueue.take(before.playbackQueue.length),
        before.playbackQueue,
      );
      expect(after.playbackQueue.skip(before.playbackQueue.length).toSet(), {
        11,
        12,
      });
    });

    test('ao ocultar faixas, ajusta o índice e mantém a atual', () {
      queue.regenerate(
        tracks: library,
        shuffleActive: false,
        currentTrackId: 5,
      );
      final hidden = {1, 2};

      queue.syncWithLibrary(
        tracks: library.where((t) => !hidden.contains(t.id)).toList(),
        shuffleActive: false,
        currentTrackId: 5,
      );
      final state = container.read(queueNotifierProvider);

      expect(state.currentQueueIndex, 2);
      expect(state.playbackQueue[state.currentQueueIndex], 5);
      expect(state.playbackQueue, isNot(containsAny(hidden)));
    });

    test(
      'fila de artista, álbum ou playlist não recebe faixas da biblioteca',
      () {
        queue.setQueue(orderedIds: [1, 2, 3], shuffleActive: false);

        queue.syncWithLibrary(
          tracks: library,
          shuffleActive: false,
          currentTrackId: 1,
        );

        expect(container.read(queueNotifierProvider).playbackQueue, [1, 2, 3]);
      },
    );
  });
}

/// Passa quando a lista contém pelo menos um dos [values].
Matcher containsAny(Set<int> values) => predicate<List<int>>(
  (list) => list.any(values.contains),
  'contém algum de $values',
);
