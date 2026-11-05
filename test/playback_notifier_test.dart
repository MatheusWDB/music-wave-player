import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/music_audio_handler_provider.dart';
import 'package:music_wave_player/providers/playback_notifier.dart';
import 'package:music_wave_player/providers/queue_notifier.dart';
import 'package:music_wave_player/services/music_audio_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAudioHandler extends Mock implements MusicAudioHandler {}

// Mesmas chaves de SharedPreferences usadas pelo PlaybackNotifier.
const _kLastPlayedMusicId = 'lastPlayedMusicId';
const _kLastSeekPositionMs = 'lastSeekPositionMs';
const _kLastSeekTrackId = 'lastSeekTrackId';

MusicTrack _track(int id) => MusicTrack(
  id: id,
  path: '/music/$id.mp3',
  title: 'Faixa $id',
  artist: 'Artista',
  album: 'Álbum',
);

// O notifier grava as preferências sem await; uma volta no event loop
// basta para as gravações terminarem.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAudioHandler handler;
  final library = List.generate(10, (i) => _track(i + 1));

  ProviderContainer newContainer() {
    final container = ProviderContainer(
      overrides: [musicAudioHandlerProvider.overrideWithValue(handler)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    handler = _MockAudioHandler();
    when(() => handler.diag(any())).thenReturn(null);
    when(() => handler.pause()).thenAnswer((_) async {});
    SharedPreferences.setMockInitialValues({
      _kLastPlayedMusicId: 10,
      _kLastSeekPositionMs: 5000,
      _kLastSeekTrackId: 10,
    });
  });

  group('C2 - fim da fila sem repeat', () {
    test('pausa, esvazia a fila e limpa o estado de reprodução', () async {
      final container = newContainer();
      await container.read(playbackNotifierProvider.future);
      // Faixa 10 é a última da fila; repeat desligado por padrão.
      container
          .read(queueNotifierProvider.notifier)
          .regenerate(
            tracks: library,
            shuffleActive: false,
            currentTrackId: 10,
          );

      container
          .read(playbackNotifierProvider.notifier)
          .playNextTrack(indexedTracks: library, isAutoAdvance: true);
      await _settle();

      final playback = container.read(playbackNotifierProvider).requireValue;
      final queue = container.read(queueNotifierProvider);
      expect(playback.lastPlayedMusicId, isNull);
      expect(playback.isPlaying, isFalse);
      expect(queue.playbackQueue, isEmpty);
      expect(queue.currentQueueIndex, -1);
      verify(() => handler.pause()).called(1);
    });

    test('apaga da persistência a última faixa e a posição salva', () async {
      final container = newContainer();
      await container.read(playbackNotifierProvider.future);
      container
          .read(queueNotifierProvider.notifier)
          .regenerate(
            tracks: library,
            shuffleActive: false,
            currentTrackId: 10,
          );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_kLastPlayedMusicId), 10);

      container
          .read(playbackNotifierProvider.notifier)
          .playNextTrack(indexedTracks: library, isAutoAdvance: true);
      await _settle();

      expect(prefs.getInt(_kLastPlayedMusicId), isNull);
      expect(prefs.getInt(_kLastSeekPositionMs), isNull);
      expect(prefs.getInt(_kLastSeekTrackId), isNull);
    });

    test('ao reabrir o app, não volta para a última faixa', () async {
      final first = newContainer();
      await first.read(playbackNotifierProvider.future);
      first
          .read(queueNotifierProvider.notifier)
          .regenerate(
            tracks: library,
            shuffleActive: false,
            currentTrackId: 10,
          );
      first
          .read(playbackNotifierProvider.notifier)
          .playNextTrack(indexedTracks: library, isAutoAdvance: true);
      await _settle();

      // Novo container = app reaberto, lendo só o que foi persistido.
      final second = newContainer();
      final reopened = await second.read(playbackNotifierProvider.future);

      expect(reopened.lastPlayedMusicId, isNull);
      expect(reopened.lastSeekPositionMs, 0);
    });
  });
}
