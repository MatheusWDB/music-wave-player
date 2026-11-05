import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/providers/custom_images_provider.dart';
import 'package:music_wave_player/services/custom_image_service.dart';

enum _ImageAction { pick, remove }

/// Bottom sheet para escolher ou remover a imagem personalizada de uma
/// playlist, artista ou álbum. Executa a ação escolhida e avisa em caso
/// de falha.
class CustomImageOptionsSheet {
  CustomImageOptionsSheet._();

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required CustomImageType type,
    required String entityKey,
  }) async {
    // Capturados antes do await: o contexto pode sair da árvore enquanto
    // o seletor de arquivos está aberto.
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(customImagesProvider.notifier);
    final hasImage =
        ref.read(customImagesProvider).pathFor(type, entityKey) != null;

    final action = await showModalBottomSheet<_ImageAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Escolher imagem'),
              onTap: () => Navigator.pop(sheetContext, _ImageAction.pick),
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remover imagem'),
                onTap: () => Navigator.pop(sheetContext, _ImageAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;

    switch (action) {
      case _ImageAction.pick:
        final result = await notifier.pick(type, entityKey);
        if (result == CustomImagePickResult.failed) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Não foi possível usar essa imagem.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      case _ImageAction.remove:
        await notifier.remove(type, entityKey);
    }
  }
}
