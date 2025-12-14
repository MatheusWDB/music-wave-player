import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:provider/provider.dart';

class FullPlayerScreen extends StatelessWidget {
  final int? initialTrackId;

  const FullPlayerScreen({super.key, this.initialTrackId});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<Configuration>();
    final colorScheme = Theme.of(context).colorScheme;
    final currentTrack = config.currentTrack;
    final activeTrackId = config.lastPlayedMusicId;

    if (currentTrack == null) {
      if (initialTrackId != null && activeTrackId != initialTrackId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          config.playTrack(initialTrackId!);
        });
        return const Center(child: CircularProgressIndicator());
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Player'),
          backgroundColor: colorScheme.surface,
        ),
        body: Center(
          child: Text(
            'Nenhuma faixa selecionada ou biblioteca vazia.',
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
      );
    }

    String formatDuration(int ms) {
      final Duration duration = Duration(milliseconds: ms);
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return "$minutes:$seconds";
    }

    final currentPositionFormatted = formatDuration(config.currentPositionMs);
    final totalDurationFormatted = formatDuration(config.trackDurationMs);
    final progressValue = config.trackDurationMs > 0
        ? config.currentPositionMs / config.trackDurationMs
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: const Text('LocalPlay'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 40.0),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Icon(
                  Icons.album,
                  size: 150,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            Text(
              currentTrack.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              currentTrack.artist,
              style: TextStyle(fontSize: 18, color: colorScheme.onSurface),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 32),
            LinearProgressIndicator(
              value: progressValue,
              color: colorScheme.primary,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currentPositionFormatted,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  Text(
                    totalDurationFormatted,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: config.isShuffleActive
                        ? colorScheme.primary
                        : colorScheme.secondary,
                  ),
                  iconSize: 32,
                  onPressed: config.toggleShuffle,
                ),
                IconButton(
                  icon: Icon(Icons.skip_previous, color: colorScheme.primary),
                  iconSize: 48,
                  onPressed: config.playPreviousTrack,
                ),
                IconButton(
                  icon: Icon(
                    config.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: colorScheme.primary,
                  ),
                  iconSize: 72,
                  onPressed: config.togglePlayPause,
                ),
                IconButton(
                  icon: Icon(Icons.skip_next, color: colorScheme.primary),
                  iconSize: 48,
                  onPressed: config.playNextTrack,
                ),
                IconButton(
                  icon: Icon(
                    config.repeatMode == 'One'
                        ? Icons.repeat_one
                        : Icons.repeat,
                    color: config.repeatMode == 'Off'
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                  iconSize: 32,
                  onPressed: config.toggleRepeatMode,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
