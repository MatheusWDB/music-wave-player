import 'package:flutter/material.dart';
import 'package:music_wave_player/services/saf_service.dart';

/// Garante o acesso SAF à pasta raiz da biblioteca antes de gravar arquivos.
///
/// Na primeira vez explica o motivo do seletor de pasta do Android e recusa
/// qualquer pasta diferente de [rootPath], repetindo o pedido até o usuário
/// acertar ou cancelar. Retorna false se o usuário desistir.
Future<bool> ensureLibraryFolderAccess(
  BuildContext context,
  String rootPath,
) async {
  if (await SafService.getSavedUri() != null) return true;

  while (true) {
    if (!context.mounted) return false;
    final proceed = await _showExplanation(context, rootPath);
    if (!proceed) return false;

    switch (await SafService.requestRootAccess(rootPath)) {
      case SafAccessResult.granted:
        return true;
      case SafAccessResult.cancelled:
        return false;
      case SafAccessResult.wrongFolder:
        if (!context.mounted) return false;
        await _showWrongFolder(context, rootPath);
    }
  }
}

String _folderName(String path) {
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  return parts.isEmpty ? path : parts.last;
}

Future<bool> _showExplanation(BuildContext context, String rootPath) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Permissão da pasta'),
      content: Text(
        'Para salvar as músicas, o Android pede que você selecione a pasta '
        'da sua biblioteca: "${_folderName(rootPath)}" ($rootPath).\n\n'
        'Selecione exatamente essa pasta. Isso é pedido só uma vez.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Escolher pasta'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<void> _showWrongFolder(BuildContext context, String rootPath) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Pasta incorreta'),
      content: Text(
        'A pasta escolhida não é a da biblioteca. Selecione "$rootPath" '
        'para que as músicas apareçam no app.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tentar de novo'),
        ),
      ],
    ),
  );
}
