import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/models/music_track.dart';

/// Item destacado exibindo a faixa atualmente tocando no topo da fila,
/// com botão de play/pause.
class CurrentQueueTile extends StatelessWidget {
  final MusicTrack track;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const CurrentQueueTile({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: colorScheme.primary, width: 3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 12, right: 8),
        leading: CoverArtWidget(
          coverPath: track.coverPath,
          size: 44,
          borderRadius: BorderRadius.circular(6),
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.primary.withValues(alpha: 0.8),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Tocando agora',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle : Icons.play_circle,
            color: colorScheme.primary,
            size: 32,
          ),
          onPressed: onPlayPause,
        ),
      ),
    );
  }
}
