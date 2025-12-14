import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:provider/provider.dart';

class MiniPlayerComponent extends StatelessWidget {
  const MiniPlayerComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final config = context.watch<Configuration>();

    MusicTrack? currentTrack;

    currentTrack =
        config.lastPlayedMusicId != null && config.indexedTracks.isNotEmpty
        ? config.indexedTracks.firstWhere(
            (track) => track.id == config.lastPlayedMusicId,
            orElse: () => config.indexedTracks.first,
          )
        : null;

    // Código temporário para enxegar o mini player
    if (currentTrack == null && config.indexedTracks.isNotEmpty) {
      currentTrack = config.indexedTracks.first;
    }

    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 65.0,
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            width: 45.0,
            height: 45.0,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(5.0),
            ),
            child: Icon(
              Icons.music_note,
              color: colorScheme.onPrimaryContainer,
              size: 28.0,
            ),
          ),
          const SizedBox(width: 10.0),
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
          IconButton(
            onPressed: config.playPreviousTrack,
            icon: Icon(Icons.skip_previous, color: colorScheme.primary),
            iconSize: 28.0,
          ),
          IconButton(
            onPressed: config.togglePlayPause,
            icon: Icon(config.isPlaying ? Icons.pause : Icons.play_arrow),
            iconSize: 32.0,
          ),
          IconButton(
            onPressed: config.playNextTrack,
            icon: Icon(Icons.skip_next, color: colorScheme.primary),
            iconSize: 28.0,
          ),
        ],
      ),
    );
  }
}
