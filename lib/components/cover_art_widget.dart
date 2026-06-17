import 'dart:io';

import 'package:flutter/material.dart';

/// Exibe a capa de álbum de uma faixa.
/// Se [coverPath] for null ou o arquivo não existir, exibe um ícone de nota musical.
///
/// Aceita [size] fixo ou [double.infinity] — nesse caso usa LayoutBuilder
/// para calcular o tamanho real disponível e dimensionar o ícone corretamente.
class CoverArtWidget extends StatelessWidget {
  final String? coverPath;
  final double size;
  final BorderRadius? borderRadius;

  const CoverArtWidget({
    super.key,
    required this.coverPath,
    required this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(8);

    // Se size for finito, usa diretamente no SizedBox
    // Se for infinito (ex: no FullPlayerScreen), deixa o pai definir o tamanho
    final Widget child = coverPath != null
        ? Image.file(
            File(coverPath!),
            fit: BoxFit.cover,
            width: size.isFinite ? size : null,
            height: size.isFinite ? size : null,
            errorBuilder: (_, __, ___) =>
                _Placeholder(colorScheme: colorScheme),
          )
        : _Placeholder(colorScheme: colorScheme);

    return ClipRRect(
      borderRadius: radius,
      child: size.isFinite
          ? SizedBox(width: size, height: size, child: child)
          : SizedBox.expand(child: child),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final ColorScheme colorScheme;
  const _Placeholder({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Usa o menor lado disponível para calcular o tamanho do ícone
        final available = constraints.biggest.shortestSide;
        final iconSize = available.isFinite ? available * 0.55 : 48.0;
        return Container(
          color: colorScheme.primaryContainer,
          child: Icon(
            Icons.music_note,
            color: colorScheme.onPrimaryContainer,
            size: iconSize,
          ),
        );
      },
    );
  }
}
