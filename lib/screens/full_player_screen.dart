import 'package:flutter/material.dart';
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
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/services/timer_service.dart';
import 'package:provider/provider.dart';

class FullPlayerScreen extends StatefulWidget {
  final int? initialTrackId;
  const FullPlayerScreen({super.key, this.initialTrackId});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen>
    with SingleTickerProviderStateMixin {
  double? _draggingValue;

  @override
  Widget build(BuildContext context) {
    final currentTrack = context.select<Configuration, MusicTrack?>(
      (c) => c.currentTrack,
    );
    final isPlaying = context.select<Configuration, bool>((c) => c.isPlaying);
    final isShuffleActive = context.select<Configuration, bool>(
      (c) => c.isShuffleActive,
    );
    final repeatMode = context.select<Configuration, String>(
      (c) => c.repeatMode,
    );
    final timerActive = context.select<SleepTimerService, bool>(
      (t) => t.isActive,
    );
    final config = context.read<Configuration>();
    final colorScheme = Theme.of(context).colorScheme;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (currentTrack == null) {
      if (widget.initialTrackId != null &&
          config.lastPlayedMusicId != widget.initialTrackId) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => config.playTrack(widget.initialTrackId!),
        );
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
        config.seekTo(v.toInt());
        setState(() => _draggingValue = null);
      },
    );

    final playbackSpeed = context.select<Configuration, double>(
      (c) => c.playbackSpeed,
    );

    final controls = PlaybackControlsRow(
      isPlaying: isPlaying,
      isShuffleActive: isShuffleActive,
      repeatMode: repeatMode,
      playbackSpeed: playbackSpeed,
      onShuffleToggle: config.toggleShuffle,
      onPrevious: config.playPreviousTrack,
      onPlayPause: config.togglePlayPause,
      onNext: config.playNextTrack,
      onRepeatToggle: config.toggleRepeatMode,
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
