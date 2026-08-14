import 'package:flutter/material.dart';

/// Seção de restauração de backup: explicação do processo e botão para
/// selecionar o arquivo .mwp.
class BackupRestoreSection extends StatelessWidget {
  final bool isPicking;
  final VoidCallback onImport;

  const BackupRestoreSection({
    super.key,
    required this.isPicking,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESTAURAR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Selecione um arquivo .mwp. A restauração roda em segundo plano — você pode navegar para outra tela enquanto isso.',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isPicking ? null : onImport,
          icon: isPicking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.file_open_outlined),
          label: const Text('Selecionar arquivo (.mwp)'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
