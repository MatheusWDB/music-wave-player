import 'package:flutter/material.dart';

/// Barra flutuante de ação exibida quando há músicas ocultas selecionadas,
/// com opção de reexibi-las. Fica ancorada na base da tela.
class UnhideActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onUnhide;

  const UnhideActionBar({
    super.key,
    required this.selectedCount,
    required this.onClear,
    required this.onUnhide,
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
            FilledButton.icon(
              onPressed: onUnhide,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Reexibir'),
            ),
          ],
        ),
      ),
    );
  }
}
