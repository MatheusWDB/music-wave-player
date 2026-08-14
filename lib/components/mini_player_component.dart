import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/favorite_button.dart';
import 'package:music_wave_player/components/mini_player_controls.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';
import 'package:provider/provider.dart';

class MiniPlayerComponent extends StatelessWidget {
  const MiniPlayerComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final config = context.watch<Configuration>();

    final MusicTrack? currentTrack = config.currentTrack;
    if (currentTrack == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        final int trackId = currentTrack.id!;
        config.playTrack(trackId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullPlayerScreen(initialTrackId: trackId),
          ),
        );
      },
      child: Container(
        height: 65.0,
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Row(
          children: [
            CoverArtWidget(
              coverPath: currentTrack.coverPath,
              size: 45,
              borderRadius: BorderRadius.circular(5),
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
                      color: colorScheme.onSurfaceVariant,
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
            FavoriteButton(trackId: currentTrack.id!, iconSize: 22),
            MiniPlayerControls(
              isPlaying: config.isPlaying,
              onPrevious: config.playPreviousTrack,
              onPlayPause: config.togglePlayPause,
              onNext: config.playNextTrack,
            ),
          ],
        ),
      ),
    );
  }
}
