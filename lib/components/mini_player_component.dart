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
    final positionMs = ref.watch(
      playbackNotifierProvider.select(
        (s) => s.valueOrNull?.currentPositionMs ?? 0,
      ),
    );
    final durationMs = ref.watch(
      playbackNotifierProvider.select(
        (s) => s.valueOrNull?.trackDurationMs ?? 0,
      ),
    );
    final indexedTracks =
        ref.watch(indexingNotifierProvider).valueOrNull?.indexedTracks ??
        const <MusicTrack>[];

    final double progress = durationMs > 0
        ? (positionMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullPlayerScreen(initialTrackId: currentTrack.id!),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(color: colorScheme.surface),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 72.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 6.0,
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
              ),
              LinearProgressIndicator(
                value: progress,
                minHeight: 2.0,
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
