import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/services/custom_image_service.dart';

/// Mapa 'tipo:chave' -> caminho da imagem personalizada. Compartilhado por
/// abas e telas de detalhe, para que uma troca apareça em todas.
final customImagesProvider =
    AsyncNotifierProvider<CustomImagesNotifier, Map<String, String>>(
      CustomImagesNotifier.new,
    );

class CustomImagesNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() => CustomImageService.loadAll();

  Future<CustomImagePickResult> pick(CustomImageType type, String key) async {
    final result = await CustomImageService.pickAndSave(type, key);
    if (result == CustomImagePickResult.saved) await reload();
    return result;
  }

  Future<void> remove(CustomImageType type, String key) async {
    await CustomImageService.remove(type, key);
    await reload();
  }

  Future<void> reload() async {
    state = AsyncData(await CustomImageService.loadAll());
  }
}

extension CustomImagesLookup on AsyncValue<Map<String, String>> {
  String? pathFor(CustomImageType type, String key) =>
      valueOrNull?[CustomImageService.mapKey(type, key)];
}
