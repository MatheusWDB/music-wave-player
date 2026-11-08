import 'package:flutter/material.dart';

/// Botão redondo de play/pausa (círculo preenchido com a cor primária).
class RoundPlayButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isPlaying;
  final double size;

  const RoundPlayButton({
    super.key,
    required this.onPressed,
    this.isPlaying = false,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      tooltip: isPlaying ? 'Pausar' : 'Tocar',
      onPressed: onPressed,
      iconSize: size * 0.58,
      style: IconButton.styleFrom(fixedSize: Size.square(size)),
      // Cor explícita: sem ela o ícone herda o cinza do iconTheme do app.
      icon: Icon(
        isPlaying ? Icons.pause : Icons.play_arrow,
        color: colorScheme.onPrimary,
      ),
    );
  }
}
