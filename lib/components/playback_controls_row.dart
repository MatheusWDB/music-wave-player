import 'package:flutter/material.dart';
import 'package:music_wave_player/components/speed_bottom_sheet.dart';

/// Linha de controles de reprodução do Full Player: shuffle, anterior,
/// play/pause, próxima, repeat e atalho de velocidade.
class PlaybackControlsRow extends StatelessWidget {
  final bool isPlaying;
  final bool isShuffleActive;
  final String repeatMode;
  final double playbackSpeed;
  final VoidCallback onShuffleToggle;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onRepeatToggle;

  const PlaybackControlsRow({
    super.key,
    required this.isPlaying,
    required this.isShuffleActive,
    required this.repeatMode,
    required this.playbackSpeed,
    required this.onShuffleToggle,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onRepeatToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(
                Icons.shuffle,
                color: isShuffleActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              iconSize: 26,
              onPressed: onShuffleToggle,
            ),
            IconButton(
              icon: Icon(Icons.skip_previous, color: colorScheme.primary),
              iconSize: 44,
              onPressed: onPrevious,
            ),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: colorScheme.onPrimary,
                ),
                iconSize: 38,
                padding: const EdgeInsets.all(10),
                onPressed: onPlayPause,
              ),
            ),
            IconButton(
              icon: Icon(Icons.skip_next, color: colorScheme.primary),
              iconSize: 44,
              onPressed: onNext,
            ),
            IconButton(
              icon: Icon(
                repeatMode == 'One' ? Icons.repeat_one : Icons.repeat,
                color: repeatMode == 'Off'
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
              ),
              iconSize: 26,
              onPressed: onRepeatToggle,
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () => SpeedBottomSheet.show(context),
          icon: Icon(
            Icons.speed,
            size: 16,
            color: playbackSpeed != 1.0
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          label: Text(
            playbackSpeed == 1.0 ? 'Normal' : '${playbackSpeed}x',
            style: TextStyle(
              fontSize: 13,
              color: playbackSpeed != 1.0
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
