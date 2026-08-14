import 'package:flutter/material.dart';

/// Barra flutuante de ações exibida quando há músicas selecionadas em uma
/// lista (modo de seleção múltipla). Fica ancorada na base da tela.
class SelectionActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onHide;
  final VoidCallback onFavorite;
  final VoidCallback onAddToPlaylist;

  const SelectionActionBar({
    super.key,
    required this.selectedCount,
    required this.onClear,
    required this.onHide,
    required this.onFavorite,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close),
              tooltip: 'Cancelar seleção',
            ),
            Expanded(
              child: Text(
                '$selectedCount selecionada${selectedCount == 1 ? '' : 's'}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: onHide,
              icon: const Icon(Icons.visibility_off_outlined),
              tooltip: 'Ocultar',
              color: colorScheme.onSurfaceVariant,
            ),
            IconButton(
              onPressed: onFavorite,
              icon: const Icon(Icons.favorite_border),
              tooltip: 'Favoritar',
              color: colorScheme.error,
            ),
            FilledButton.icon(
              onPressed: onAddToPlaylist,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }
}
