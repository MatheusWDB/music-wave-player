import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/models/playlist.dart';
import 'package:music_wave_player/providers/music_audio_handler_provider.dart';
import 'package:music_wave_player/providers/queue_notifier.dart';
import 'package:music_wave_player/services/recently_played_service.dart';

part 'playback_notifier.g.dart';

const String _kLastPlayedMusicIdKey = 'lastPlayedMusicId';
const String _kLastSeekPositionMsKey = 'lastSeekPositionMs';
// Faixa à qual a posição salva pertence — sem isso, a posição da faixa
// anterior podia ser lida junto com o id da faixa nova na próxima abertura.
const String _kLastSeekTrackIdKey = 'lastSeekTrackId';
const String _kShuffleActiveKey = 'shuffleActive';

/// Estado imutável de reprodução: faixa atual, posição, duração, repeat
/// e histórico de reproduzidas recentemente.
class PlaybackState {
  final int? lastPlayedMusicId;
  final int lastSeekPositionMs;
  final int currentPositionMs;
  final int trackDurationMs;
  final bool isPlaying;
  final bool isShuffleActive;
  final String repeatMode;
  final List<int> recentlyPlayedIds;

  const PlaybackState({
    this.lastPlayedMusicId,
    this.lastSeekPositionMs = 0,
    this.currentPositionMs = 0,
    this.trackDurationMs = 0,
    this.isPlaying = false,
    this.isShuffleActive = false,
    this.repeatMode = 'Off',
    this.recentlyPlayedIds = const [],
  });

  PlaybackState copyWith({
    int? lastPlayedMusicId,
    bool clearLastPlayedMusicId = false,
    int? lastSeekPositionMs,
    int? currentPositionMs,
    int? trackDurationMs,
    bool? isPlaying,
    bool? isShuffleActive,
    String? repeatMode,
    List<int>? recentlyPlayedIds,
  }) {
    return PlaybackState(
      lastPlayedMusicId: clearLastPlayedMusicId
          ? null
          : (lastPlayedMusicId ?? this.lastPlayedMusicId),
      lastSeekPositionMs: lastSeekPositionMs ?? this.lastSeekPositionMs,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      trackDurationMs: trackDurationMs ?? this.trackDurationMs,
      isPlaying: isPlaying ?? this.isPlaying,
      isShuffleActive: isShuffleActive ?? this.isShuffleActive,
      repeatMode: repeatMode ?? this.repeatMode,
      recentlyPlayedIds: recentlyPlayedIds ?? this.recentlyPlayedIds,
    );
  }
}

/// Coordena as ações de reprodução: play, pause, next, previous, repeat.
/// Substitui o antigo [PlaybackController] — depende de [QueueNotifier]
/// para navegação na fila e de [musicAudioHandlerProvider] para controle
/// do player de áudio.
@Riverpod(keepAlive: true)
class PlaybackNotifier extends _$PlaybackNotifier {
  // Quantas trocas de faixa estão em andamento (state já com o id novo,
  // mas o player ainda não carregou a faixa). Enquanto > 0, saves de
  // posição são ignorados — leriam a posição da faixa anterior.
  int _switchingTracks = 0;

  @override
  Future<PlaybackState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final recentlyPlayedIds = await RecentlyPlayedService.load();

    final lastPlayedId = prefs.getInt(_kLastPlayedMusicIdKey);
    // Só aproveita a posição salva se ela for da mesma faixa que está
    // marcada como última tocada; senão (ex: pausou logo no começo de uma
    // faixa nova, antes de qualquer save dela) volta pro início.
    final seekBelongsToLastTrack =
        lastPlayedId != null &&
        prefs.getInt(_kLastSeekTrackIdKey) == lastPlayedId;

    return PlaybackState(
      lastPlayedMusicId: lastPlayedId,
      lastSeekPositionMs: seekBelongsToLastTrack
          ? (prefs.getInt(_kLastSeekPositionMsKey) ?? 0)
          : 0,
      isShuffleActive: prefs.getBool(_kShuffleActiveKey) ?? false,
      recentlyPlayedIds: recentlyPlayedIds,
    );
  }

  // ── Reprodução ────────────────────────────────────────────────────────────

  Future<void> playTrack(
    int musicId, {
    required List<MusicTrack> indexedTracks,
    required String? trackPath,
    // Faixas do contexto de origem (artista, álbum, playlist). Quando
    // informado, a fila é criada só com elas, em vez da biblioteca inteira.
    List<MusicTrack>? contextTracks,
    bool regenerateQueue = true,
    bool autoplay = true,
    // true só quando essa troca de faixa veio do fim natural da anterior
    // (ver trackDidFinish) — único caso em que o fade ao iniciar deve
    // acontecer. Retomar da pausa e pular manualmente ficam sem fade.
    bool isAutoAdvance = false,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final exists = indexedTracks.any((t) => t.id == musicId);
    if (!exists || trackPath == null) return;

    final audioHandler = ref.read(musicAudioHandlerProvider);
    final queueNotifier = ref.read(queueNotifierProvider.notifier);

    // DIAGNÓSTICO TEMPORÁRIO — remover junto com o resto
    audioHandler.diag(
      'playTrack: id=$musicId, anterior=${current.lastPlayedMusicId}, '
      'regenerateQueue=$regenerateQueue, autoplay=$autoplay, '
      'autoAdvance=$isAutoAdvance, aleatório=${current.isShuffleActive}',
    );

    if (current.lastPlayedMusicId != musicId) {
      List<int> recentlyPlayedIds = current.recentlyPlayedIds;
      if (current.lastPlayedMusicId != null) {
        recentlyPlayedIds = await RecentlyPlayedService.push(
          current.lastPlayedMusicId!,
          current.recentlyPlayedIds,
        );
      }

      if (regenerateQueue) {
        // Com o aleatório ligado a faixa escolhida abre a fila e o resto é
        // embaralhado. Antes isso passava shuffleActive: false, deixando o
        // botão marcado como aleatório com a fila em ordem original.
        final scoped = contextTracks?.where((t) => !t.isHidden).toList();
        final useContext = scoped != null && scoped.isNotEmpty;
        queueNotifier.regenerate(
          tracks: useContext ? scoped : indexedTracks,
          shuffleActive: current.isShuffleActive,
          currentTrackId: musicId,
          isLibraryContext: !useContext,
        );
      }
      queueNotifier.syncCurrentIndex(musicId);

      _switchingTracks++;
      try {
        state = AsyncData(
          current.copyWith(
            lastPlayedMusicId: musicId,
            lastSeekPositionMs: 0,
            currentPositionMs: 0,
            trackDurationMs: 0,
            recentlyPlayedIds: recentlyPlayedIds,
          ),
        );

        await _saveLastPlayedMusicId(musicId);
        // Zera a posição salva já pareada com o id novo — antes ela
        // continuava com o valor da faixa anterior até o próximo save.
        await _saveLastSeekPosition(0);
        await audioHandler.loadTrack(trackPath);
      } finally {
        _switchingTracks--;
      }

      if (autoplay) {
        state = AsyncData(state.valueOrNull!.copyWith(isPlaying: true));
        audioHandler.play(isAutoAdvance: isAutoAdvance);
      } else {
        state = AsyncData(state.valueOrNull!.copyWith(isPlaying: false));
      }
      return;
    }

    // Mesma faixa que já está carregada: só retoma se estava pausada.
    if (autoplay && !current.isPlaying) {
      state = AsyncData(current.copyWith(isPlaying: true));
      audioHandler.play(isAutoAdvance: isAutoAdvance);
    }
  }

  Future<void> playPlaylist(
    Playlist playlist, {
    required List<MusicTrack> indexedTracks,
    required bool shuffleActive,
    required String? Function(int id) pathForId,
    bool randomStart = false,
  }) async {
    if (playlist.trackIds.isEmpty) return;
    final validIds = playlist.trackIds
        .where((id) => indexedTracks.any((t) => t.id == id))
        .toList();
    if (validIds.isEmpty) return;

    ref
        .read(queueNotifierProvider.notifier)
        .setQueue(
          orderedIds: validIds,
          shuffleActive: shuffleActive,
          randomStart: randomStart,
        );
    await _startFromQueueTop(pathForId: pathForId);
  }

  Future<void> playTracks(
    List<MusicTrack> tracks, {
    required bool shuffleActive,
    required String? Function(int id) pathForId,
    bool randomStart = false,
  }) async {
    final visibleIds = tracks
        .where((t) => !t.isHidden)
        .map((t) => t.id!)
        .toList();
    if (visibleIds.isEmpty) return;

    ref
        .read(queueNotifierProvider.notifier)
        .setQueue(
          orderedIds: visibleIds,
          shuffleActive: shuffleActive,
          randomStart: randomStart,
        );
    await _startFromQueueTop(pathForId: pathForId);
  }

  Future<void> _startFromQueueTop({
    required String? Function(int id) pathForId,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final queue = ref.read(queueNotifierProvider).playbackQueue;
    final firstId = queue.first;
    final path = pathForId(firstId);
    if (path == null) return;

    final audioHandler = ref.read(musicAudioHandlerProvider);

    _switchingTracks++;
    try {
      state = AsyncData(
        current.copyWith(
          lastPlayedMusicId: firstId,
          lastSeekPositionMs: 0,
          currentPositionMs: 0,
          trackDurationMs: 0,
        ),
      );

      await _saveLastPlayedMusicId(firstId);
      await _saveLastSeekPosition(0);
      await audioHandler.loadTrack(path);
    } finally {
      _switchingTracks--;
    }

    state = AsyncData(state.valueOrNull!.copyWith(isPlaying: true));
    audioHandler.play();
  }

  // ── Controles ─────────────────────────────────────────────────────────────

  void togglePlayPause({
    required List<MusicTrack> indexedTracks,
    required String? currentTrackPath,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;

    final audioHandler = ref.read(musicAudioHandlerProvider);
    final queueNotifier = ref.read(queueNotifierProvider.notifier);

    // Nenhuma faixa carregada — inicia com a primeira da fila
    if (current.lastPlayedMusicId == null && indexedTracks.isNotEmpty) {
      final queue = ref.read(queueNotifierProvider).playbackQueue;
      if (queue.isEmpty) return;

      final id = queue.first;
      queueNotifier.setCurrentIndex(0);
      _saveLastPlayedMusicId(id);

      state = AsyncData(
        current.copyWith(lastPlayedMusicId: id, isPlaying: true),
      );
      _saveLastSeekPosition(0);

      if (currentTrackPath != null) {
        _switchingTracks++;
        audioHandler
            .loadTrack(currentTrackPath)
            .then((_) {
              audioHandler.play();
            })
            .whenComplete(() => _switchingTracks--);
      }
      return;
    }

    if (current.lastPlayedMusicId == null) return;

    final nowPlaying = !current.isPlaying;
    state = AsyncData(current.copyWith(isPlaying: nowPlaying));

    if (nowPlaying) {
      // Se a pausa atual veio do temporizador ao fim da faixa, avança para
      // a próxima em vez de retomar do zero.
      final pausedAtEnd = audioHandler.consumePausedAtTrackEnd();
      if (pausedAtEnd) {
        playNextTrack(indexedTracks: indexedTracks);
      } else {
        audioHandler.play();
      }
    } else {
      _saveLastSeekPosition(current.currentPositionMs);
      audioHandler.pause();
    }
  }

  void playNextTrack({
    required List<MusicTrack> indexedTracks,
    bool isAutoAdvance = false,
  }) {
    final queueNotifier = ref.read(queueNotifierProvider.notifier);
    final queueState = ref.read(queueNotifierProvider);
    final queue = queueState.playbackQueue;
    if (queue.isEmpty) return;

    final current = state.valueOrNull;
    if (current == null) return;

    // DIAGNÓSTICO TEMPORÁRIO — remover junto com o resto. Mostra os
    // títulos das próximas faixas da fila no momento do avanço: se o
    // aleatório estiver ligado e elas aparecerem em ordem
    // alfabética/sequencial, a fila NÃO está embaralhada de verdade.
    final audioHandlerForLog = ref.read(musicAudioHandlerProvider);
    String titleOf(int id) =>
        indexedTracks.where((t) => t.id == id).firstOrNull?.title ?? '#$id';
    final upcomingPreview = queue
        .skip(queueState.currentQueueIndex + 1)
        .take(5)
        .map(titleOf)
        .join(' | ');
    audioHandlerForLog.diag(
      'playNextTrack: autoAdvance=$isAutoAdvance, '
      'aleatório=${current.isShuffleActive}, repeat=${current.repeatMode}, '
      'índice=${queueState.currentQueueIndex}/${queue.length}, '
      'próximas: [$upcomingPreview]',
    );

    int next = queueState.currentQueueIndex + 1;
    var effectiveQueue = queue;
    if (next >= queue.length) {
      if (current.repeatMode == 'All') {
        // Nova rodada: sem isso, dar a volta repetiria a mesma sequência do
        // ciclo anterior. Com aleatório, embaralha tudo de novo; sem ele,
        // volta à ordem original pura do contexto (não à ordem com o
        // histórico reordenado por trocas do aleatório).
        queueNotifier.restartCycle(
          shuffle: current.isShuffleActive,
          avoidFirstId: current.lastPlayedMusicId,
        );
        effectiveQueue = ref.read(queueNotifierProvider).playbackQueue;
        next = 0;
      } else {
        // Fila acabou e não tem repeat: limpa de vez em vez de deixar a
        // última faixa marcada como atual/pausada.
        audioHandlerForLog.diag(
          'playNextTrack: fim da fila sem repeat — limpando',
        );
        ref.read(musicAudioHandlerProvider).pause();
        queueNotifier.clearAll();
        state = AsyncData(
          current.copyWith(
            clearLastPlayedMusicId: true,
            currentPositionMs: 0,
            trackDurationMs: 0,
            isPlaying: false,
          ),
        );
        // Sem isso o id continua salvo e a fila é recriada ao reabrir o app.
        unawaited(_clearSavedLastPlayed());
        return;
      }
    }

    queueNotifier.setCurrentIndex(next);
    final trackId = effectiveQueue[next];
    final track = indexedTracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) {
      audioHandlerForLog.diag(
        'playNextTrack: faixa #$trackId (índice $next) não está em '
        'indexedTracks — avanço abortado',
      );
      return;
    }
    audioHandlerForLog.diag(
      'playNextTrack: escolhida "${track.title}" — ${track.artist} '
      '(índice $next, id $trackId)',
    );

    playTrack(
      trackId,
      indexedTracks: indexedTracks,
      trackPath: track.path,
      regenerateQueue: false,
      isAutoAdvance: isAutoAdvance,
    );
  }

  void playPreviousTrack({required List<MusicTrack> indexedTracks}) {
    final current = state.valueOrNull;
    if (current == null) return;

    final queueNotifier = ref.read(queueNotifierProvider.notifier);
    final queueState = ref.read(queueNotifierProvider);
    final queue = queueState.playbackQueue;
    if (queue.isEmpty) return;

    final audioHandler = ref.read(musicAudioHandlerProvider);

    // Se passou de 3s, volta ao início da faixa atual
    if (current.currentPositionMs > 3000) {
      audioHandler.seek(Duration.zero);
      return;
    }

    int prev = queueState.currentQueueIndex - 1;
    if (prev < 0) {
      if (current.repeatMode == 'All') {
        prev = queue.length - 1;
      } else {
        audioHandler.seek(Duration.zero);
        return;
      }
    }

    queueNotifier.setCurrentIndex(prev);
    final trackId = queue[prev];
    final track = indexedTracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return;

    playTrack(
      trackId,
      indexedTracks: indexedTracks,
      trackPath: track.path,
      regenerateQueue: false,
    );
  }

  void trackDidFinish({required List<MusicTrack> indexedTracks}) {
    final current = state.valueOrNull;
    if (current == null) return;

    final queueState = ref.read(queueNotifierProvider);
    final queue = queueState.playbackQueue;
    // DIAGNÓSTICO TEMPORÁRIO — remover junto com o resto
    ref
        .read(musicAudioHandlerProvider)
        .diag(
          'trackDidFinish: aleatório=${current.isShuffleActive}, '
          'repeat=${current.repeatMode}, '
          'faixaAtual=${current.lastPlayedMusicId}, '
          'índiceNaFila=${queueState.currentQueueIndex}/${queue.length}',
        );
    if (current.lastPlayedMusicId == null || queue.isEmpty) return;

    if (current.repeatMode == 'One') {
      final track = indexedTracks
          .where((t) => t.id == current.lastPlayedMusicId)
          .firstOrNull;
      if (track != null) {
        playTrack(
          current.lastPlayedMusicId!,
          indexedTracks: indexedTracks,
          trackPath: track.path,
          isAutoAdvance: true,
        );
      }
      return;
    }
    playNextTrack(indexedTracks: indexedTracks, isAutoAdvance: true);
  }

  void toggleShuffle() {
    final current = state.valueOrNull;
    if (current == null) return;

    final queueNotifier = ref.read(queueNotifierProvider.notifier);
    final nowActive = !current.isShuffleActive;

    final description = nowActive
        ? queueNotifier.applyShuffle()
        : queueNotifier.removeShuffle();
    // DIAGNÓSTICO TEMPORÁRIO — remover junto com o resto
    ref.read(musicAudioHandlerProvider).diag('toggleShuffle: $description');

    state = AsyncData(current.copyWith(isShuffleActive: nowActive));
    _saveShuffleActive(nowActive);
  }

  // ── Coordenação com a fila ────────────────────────────────────────────────

  /// Remove um item da fila e reage ao resultado: pausa se a faixa
  /// removida era a atual e a fila ficou vazia, ou avança para a próxima
  /// se havia uma. Coordena [QueueNotifier] + reprodução, por isso vive
  /// aqui em vez de só no QueueNotifier.
  void removeFromQueue(int index, {required List<MusicTrack> indexedTracks}) {
    final current = state.valueOrNull;
    if (current == null) return;

    final result = ref
        .read(queueNotifierProvider.notifier)
        .remove(index: index, currentTrackId: current.lastPlayedMusicId);

    switch (result) {
      case QueueRemovePause():
        ref.read(musicAudioHandlerProvider).pause();
      case QueueRemovePlayTrack(:final trackId):
        final track = indexedTracks.where((t) => t.id == trackId).firstOrNull;
        playTrack(
          trackId,
          indexedTracks: indexedTracks,
          trackPath: track?.path,
          regenerateQueue: false,
        );
      case QueueRemoveNone():
        break;
    }
  }

  /// Pula para uma posição específica da fila.
  void jumpToQueueIndex(int index, {required List<MusicTrack> indexedTracks}) {
    final queueNotifier = ref.read(queueNotifierProvider.notifier);
    final queue = ref.read(queueNotifierProvider).playbackQueue;
    if (index < 0 || index >= queue.length) return;

    queueNotifier.setCurrentIndex(index);
    final trackId = queue[index];
    final track = indexedTracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return;

    playTrack(
      trackId,
      indexedTracks: indexedTracks,
      trackPath: track.path,
      regenerateQueue: false,
    );
  }

  void toggleRepeatMode() {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = switch (current.repeatMode) {
      'Off' => 'All',
      'All' => 'One',
      _ => 'Off',
    };
    state = AsyncData(current.copyWith(repeatMode: next));
  }

  // ── Sincronização de estado vindo do player ───────────────────────────────

  void syncPlayingState(bool playing) {
    final current = state.valueOrNull;
    if (current == null || current.isPlaying == playing) return;
    state = AsyncData(current.copyWith(isPlaying: playing));
  }

  void updateCurrentPosition(int ms) {
    final current = state.valueOrNull;
    if (current == null || current.currentPositionMs == ms) return;
    state = AsyncData(current.copyWith(currentPositionMs: ms));
  }

  void updateTrackDuration(int ms) {
    final current = state.valueOrNull;
    if (current == null || current.trackDurationMs == ms) return;
    state = AsyncData(current.copyWith(trackDurationMs: ms));
  }

  Future<void> clearRecentlyPlayed() async {
    await RecentlyPlayedService.clear();
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(recentlyPlayedIds: []));
  }

  Future<void> saveCurrentPositionForResume(int ms) async {
    // Troca de faixa em andamento: a posição lida do player ainda é da
    // faixa anterior e seria gravada junto com o id da nova.
    if (_switchingTracks > 0) return;
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(lastSeekPositionMs: ms));
    }
    await _saveLastSeekPosition(ms);
  }

  /// Setter direto de posição de resume, usado pelo audio handler ao
  /// consumir o valor salvo (equivalente ao antigo `lastSeekPositionMs =`).
  void consumeLastSeekPosition() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(lastSeekPositionMs: 0));
  }

  // ── Persistência ──────────────────────────────────────────────────────────

  Future<void> _saveLastPlayedMusicId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastPlayedMusicIdKey, id);
  }

  Future<void> _clearSavedLastPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastPlayedMusicIdKey);
    await prefs.remove(_kLastSeekPositionMsKey);
    await prefs.remove(_kLastSeekTrackIdKey);
  }

  Future<void> _saveLastSeekPosition(int ms) async {
    // Lê o id de forma síncrona, antes de qualquer await — é o par
    // (faixa, posição) do momento da chamada.
    final trackId = state.valueOrNull?.lastPlayedMusicId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastSeekPositionMsKey, ms);
    if (trackId != null) {
      await prefs.setInt(_kLastSeekTrackIdKey, trackId);
    } else {
      await prefs.remove(_kLastSeekTrackIdKey);
    }
  }

  Future<void> _saveShuffleActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShuffleActiveKey, active);
  }
}
