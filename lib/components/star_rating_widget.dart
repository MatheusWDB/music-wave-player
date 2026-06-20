import 'package:flutter/material.dart';

/// Widget de avaliação por estrelas com suporte a meias estrelas.
///
/// - Toque na metade esquerda de uma estrela → meia estrela
/// - Toque na metade direita → estrela inteira
/// - Toque na estrela já selecionada exata → zera a nota
/// - [onRatingChanged] null = modo leitura
class StarRatingWidget extends StatelessWidget {
  final double rating;
  final ValueChanged<double>? onRatingChanged;
  final double starSize;
  final Color? activeColor;
  final Color? inactiveColor;

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.starSize = 32,
    this.activeColor,
    this.inactiveColor,
  });

  void _onTap(int starIndex, bool isLeftHalf) {
    if (onRatingChanged == null) return;
    final tapped = isLeftHalf ? starIndex + 0.5 : starIndex + 1.0;
    // Toque exato na nota atual → zera
    final next = tapped == rating ? 0.0 : tapped;
    onRatingChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? Theme.of(context).colorScheme.secondary;
    final inactive =
        inactiveColor ??
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3);
    final isInteractive = onRatingChanged != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        final half = !filled && rating >= i + 0.5;

        final star = SizedBox(
          width: starSize,
          height: starSize,
          child: Stack(
            children: [
              // Estrela de fundo (vazia)
              Icon(Icons.star, size: starSize, color: inactive),
              // Preenchimento: inteira ou metade
              if (filled)
                Icon(Icons.star, size: starSize, color: active)
              else if (half)
                ClipRect(
                  clipper: _HalfClipper(),
                  child: Icon(Icons.star, size: starSize, color: active),
                ),
            ],
          ),
        );

        if (!isInteractive) return star;

        // Divide a estrela em duas áreas de toque
        return GestureDetector(
          onTapDown: (details) {
            final isLeft = details.localPosition.dx < starSize / 2;
            _onTap(i, isLeft);
          },
          child: star,
        );
      }),
    );
  }
}

class _HalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(_HalfClipper old) => false;
}
