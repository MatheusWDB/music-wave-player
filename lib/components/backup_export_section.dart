import 'package:flutter/material.dart';

/// Seção de exportação de backup: explicação do conteúdo incluído e
/// botões para compartilhar ou salvar em pasta.
class BackupExportSection extends StatelessWidget {
  final bool isSharing;
  final bool isSavingToFolder;
  final VoidCallback onShare;
  final VoidCallback onSaveToFolder;

  const BackupExportSection({
    super.key,
    required this.isSharing,
    required this.isSavingToFolder,
    required this.onShare,
    required this.onSaveToFolder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXPORTAR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Inclui playlists, notas, músicas ocultas, histórico de reprodução e configurações (equalizador, ordenação, crossfade).',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSharing ? null : onShare,
                icon: isSharing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_outlined),
                label: const Text('Compartilhar'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: isSavingToFolder ? null : onSaveToFolder,
                icon: isSavingToFolder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.folder_outlined),
                label: const Text('Salvar em pasta'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
