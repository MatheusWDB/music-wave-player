import 'package:flutter/material.dart';

/// Cabeçalho da tela de configuração de biblioteca: ícone, título do app
/// e subtítulo de instrução.
class LibrarySetupHeader extends StatelessWidget {
  const LibrarySetupHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 6.0,
          children: [
            const Icon(Icons.headphones),
            Text(
              'LocalPlay',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 28.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          'Configure sua Biblioteca de Música',
          style: TextStyle(color: colorScheme.primary, fontSize: 16.0),
        ),
      ],
    );
  }
}
