import 'package:flutter/material.dart';

/// Rodapé com botões de cancelar/confirmar do bottom sheet de seleção de
/// músicas. "Confirmar" fica desabilitado quando nada está selecionado.
class TrackSelectionFooter extends StatelessWidget {
  final bool hasSelection;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const TrackSelectionFooter({
    super.key,
    required this.hasSelection,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: hasSelection ? onConfirm : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Confirmar'),
            ),
          ),
        ],
      ),
    );
  }
}
