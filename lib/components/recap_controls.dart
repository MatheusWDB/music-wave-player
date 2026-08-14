import 'package:flutter/material.dart';

/// Barra de controles do recap: fechar e compartilhar como imagem.
class RecapControls extends StatelessWidget {
  final bool isSharing;
  final VoidCallback onClose;
  final VoidCallback onShare;

  const RecapControls({
    super.key,
    required this.isSharing,
    required this.onClose,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      color: const Color(0xFF0D1B2A),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottomInset),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Fechar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: isSharing ? null : onShare,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFA8DADC),
                foregroundColor: const Color(0xFF0D1B2A),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: isSharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
              label: const Text('Compartilhar'),
            ),
          ),
        ],
      ),
    );
  }
}
