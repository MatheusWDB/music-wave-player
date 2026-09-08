import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/mini_player_controls.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/current_track_provider.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/providers/playback_notifier.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';

class MiniPlayerComponent extends ConsumerWidget {
  const MiniPlayerComponent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final MusicTrack? currentTrack = ref.watch(currentTrackProvider);
    if (currentTrack == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(
      playbackNotifierProvider.select((s) => s.valueOrNull?.isPlaying ?? false),
    );
    final indexedTracks =
        ref.watch(indexingNotifierProvider).valueOrNull?.indexedTracks ??
        const <MusicTrack>[];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullPlayerScreen(initialTrackId: currentTrack.id!),
          ),
        );
      },
      child: Container(
        height: 72.0,
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Row(
          children: [
            CoverArtWidget(
              coverPath: currentTrack.coverPath,
              size: 56,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentTrack.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentTrack.artist,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            MiniPlayerControls(
              isPlaying: isPlaying,
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
            ),
          ],
        ),
      ),
    );
  }
}
