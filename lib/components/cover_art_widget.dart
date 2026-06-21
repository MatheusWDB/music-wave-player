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
    final radius = borderRadius ?? BorderRadius.circular(8);

    // Se size for finito, usa diretamente no SizedBox
    // Se for infinito (ex: no FullPlayerScreen), deixa o pai definir o tamanho
    final Widget child = coverPath != null
        ? Image.file(
            File(coverPath!),
            fit: BoxFit.cover,
            width: size.isFinite ? size : null,
            height: size.isFinite ? size : null,
            errorBuilder: (_, __, ___) => _Placeholder(),
          )
        : _Placeholder();

    return ClipRRect(
      borderRadius: radius,
      child: size.isFinite
          ? SizedBox(width: size, height: size, child: child)
          : SizedBox.expand(child: child),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset('assets/icon/icon (1).png', fit: BoxFit.contain),
      ),
    );
  }
}
