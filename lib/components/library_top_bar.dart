import 'package:flutter/material.dart';

/// Barra superior da tela de biblioteca: título do app e atalhos rápidos
/// (histórico, busca, menu de opções).
class LibraryTopBar extends StatelessWidget {
  final VoidCallback onHistoryTap;
  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;

  const LibraryTopBar({
    super.key,
    required this.onHistoryTap,
    required this.onSearchTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'LocalPlay',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: onHistoryTap,
            icon: Icon(Icons.history, color: colorScheme.onSurface),
          ),
          IconButton(
            onPressed: onSearchTap,
            icon: Icon(Icons.search, color: colorScheme.onSurface),
          ),
          IconButton(
            onPressed: onMenuTap,
            icon: Icon(Icons.apps, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
