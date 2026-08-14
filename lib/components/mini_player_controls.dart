import 'package:flutter/material.dart';

/// Fileira de botões de controle de reprodução do mini player: anterior,
/// play/pause, próxima.
class MiniPlayerControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  const MiniPlayerControls({
    super.key,
    required this.isPlaying,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: Icon(Icons.skip_previous, color: colorScheme.primary),
          iconSize: 28.0,
        ),
        IconButton(
          onPressed: onPlayPause,
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          iconSize: 32.0,
        ),
        IconButton(
          onPressed: onNext,
          icon: Icon(Icons.skip_next, color: colorScheme.primary),
          iconSize: 28.0,
        ),
      ],
    );
  }
}
