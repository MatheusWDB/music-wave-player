import 'package:flutter/material.dart';

/// Cabeçalho do bottom sheet de fila: título e ações (salvar como playlist,
/// limpar fila, fechar). Os botões de ação só aparecem quando há próximas
/// músicas na fila.
class QueueHeaderBar extends StatelessWidget {
  final bool hasUpcomingTracks;
  final VoidCallback onSaveAsPlaylist;
  final VoidCallback onClearQueue;
  final VoidCallback onClose;

  const QueueHeaderBar({
    super.key,
    required this.hasUpcomingTracks,
    required this.onSaveAsPlaylist,
    required this.onClearQueue,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Fila de reprodução',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (hasUpcomingTracks)
            IconButton(
              icon: Icon(Icons.playlist_add, color: colorScheme.primary),
              tooltip: 'Salvar fila como playlist',
              onPressed: onSaveAsPlaylist,
            ),
          if (hasUpcomingTracks)
            IconButton(
              icon: Icon(Icons.playlist_remove, color: colorScheme.error),
              tooltip: 'Limpar fila',
              onPressed: onClearQueue,
            ),
          TextButton(onPressed: onClose, child: const Text('Fechar')),
        ],
      ),
    );
  }
}
