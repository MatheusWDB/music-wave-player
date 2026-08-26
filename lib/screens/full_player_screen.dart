import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/edit_track_bottom_sheet.dart';
import 'package:music_wave_player/components/favorite_button.dart';
import 'package:music_wave_player/components/full_player_landscape_layout.dart';
import 'package:music_wave_player/components/full_player_portrait_layout.dart';
import 'package:music_wave_player/components/full_player_star_rating.dart';
import 'package:music_wave_player/components/playback_controls_row.dart';
import 'package:music_wave_player/components/queue_bottom_sheet.dart';
import 'package:music_wave_player/components/rating_bottom_sheet.dart';
import 'package:music_wave_player/components/smooth_progress_slider.dart';
import 'package:music_wave_player/components/timer_bottom_sheet.dart';
import 'package:music_wave_player/components/track_info_header.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/current_track_provider.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/providers/music_audio_handler_provider.dart';
import 'package:music_wave_player/providers/player_settings_notifier.dart';
import 'package:music_wave_player/providers/playback_notifier.dart';
import 'package:music_wave_player/providers/timer_notifier.dart';

class FullPlayerScreen extends ConsumerStatefulWidget {
  final int? initialTrackId;
  const FullPlayerScreen({super.key, this.initialTrackId});

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen>
    with SingleTickerProviderStateMixin {
  double? _draggingValue;

  @override
  Widget build(BuildContext context) {
    final currentTrack = ref.watch(currentTrackProvider);
    final playbackState = ref.watch(playbackNotifierProvider).valueOrNull;
    final isPlaying = playbackState?.isPlaying ?? false;
    final isShuffleActive = playbackState?.isShuffleActive ?? false;
    final repeatMode = playbackState?.repeatMode ?? 'Off';
    final timerActive = ref.watch(
      timerNotifierProvider.select((s) => s.isActive),
    );
    final indexedTracks =
        ref.watch(indexingNotifierProvider).valueOrNull?.indexedTracks ??
        const <MusicTrack>[];
    final colorScheme = Theme.of(context).colorScheme;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (currentTrack == null) {
      if (widget.initialTrackId != null &&
          playbackState?.lastPlayedMusicId != widget.initialTrackId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final track = indexedTracks
              .where((t) => t.id == widget.initialTrackId)
              .firstOrNull;
          if (track != null) {
            ref
                .read(playbackNotifierProvider.notifier)
                .playTrack(
                  widget.initialTrackId!,
                  indexedTracks: indexedTracks,
                  trackPath: track.path,
                );
          }
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Player')),
        body: const Center(child: Text('Nenhuma faixa selecionada.')),
      );
    }

    final coverWidget = CoverArtWidget(
      coverPath: currentTrack.coverPath,
      size: double.infinity,
      borderRadius: BorderRadius.circular(20),
    );

    final trackInfo = TrackInfoHeader(
      title: currentTrack.title,
      artist: currentTrack.artist,
      album: currentTrack.album,
    );

    final starRating = FullPlayerStarRating(track: currentTrack);

    final slider = SmoothProgressSlider(
      draggingValue: _draggingValue,
      onDragStart: (v) => setState(() => _draggingValue = v),
      onDragUpdate: (v) => setState(() => _draggingValue = v),
      onDragEnd: (v) {
        ref
            .read(musicAudioHandlerProvider)
            .seek(Duration(milliseconds: v.toInt()));
        setState(() => _draggingValue = null);
      },
    );

    final playbackSpeed = ref.watch(
      playerSettingsNotifierProvider.select(
        (s) => s.valueOrNull?.playbackSpeed ?? 1.0,
      ),
    );

    final controls = PlaybackControlsRow(
      isPlaying: isPlaying,
      isShuffleActive: isShuffleActive,
      repeatMode: repeatMode,
      playbackSpeed: playbackSpeed,
      onShuffleToggle: () =>
          ref.read(playbackNotifierProvider.notifier).toggleShuffle(),
      onPrevious: () => ref
          .read(playbackNotifierProvider.notifier)
          .playPreviousTrack(indexedTracks: indexedTracks),
      onPlayPause: () => ref
          .read(playbackNotifierProvider.notifier)
          .togglePlayPause(
            indexedTracks: indexedTracks,
            currentTrackPath: currentTrack.path,
          ),
      onNext: () => ref
          .read(playbackNotifierProvider.notifier)
          .playNextTrack(indexedTracks: indexedTracks),
      onRepeatToggle: () =>
          ref.read(playbackNotifierProvider.notifier).toggleRepeatMode(),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: const Text('LocalPlay'),
        centerTitle: true,
        actions: [
          FavoriteButton(trackId: currentTrack.id!),
          // Botão do temporizador — muda de cor quando ativo
          IconButton(
            icon: Icon(
              Icons.bedtime_outlined,
              color: timerActive ? colorScheme.secondary : null,
            ),
            tooltip: 'Temporizador de sono',
            onPressed: () => TimerBottomSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.queue_music),
            tooltip: 'Fila de reprodução',
            onPressed: () => QueueBottomSheet.show(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                EditTrackBottomSheet.show(context, track: currentTrack);
              } else if (value == 'rate') {
                RatingBottomSheet.show(context, track: currentTrack);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 12),
                    Text('Editar informações'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'rate',
                child: Row(
                  children: [
                    Icon(Icons.star_outline),
                    SizedBox(width: 12),
                    Text('Avaliar'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: isLandscape
            ? FullPlayerLandscapeLayout(
                coverWidget: coverWidget,
                trackInfo: trackInfo,
                starRating: starRating,
                slider: slider,
                controls: controls,
              )
            : FullPlayerPortraitLayout(
                coverWidget: coverWidget,
                trackInfo: trackInfo,
                starRating: starRating,
                slider: slider,
                controls: controls,
              ),
      ),
    );
  }
}
