import 'package:flutter/material.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/playlist.dart';

/// Diálogo para escolher uma playlist existente ou criar uma nova.
///
/// Use [PickPlaylistDialog.show] em vez de instanciar diretamente — ele já
/// resolve o resultado do diálogo (playlist existente ou nome digitado)
/// para um ID de playlist pronto para uso, criando a playlist nova se
/// necessário.
class PickPlaylistDialog extends StatelessWidget {
  final List<Playlist> playlists;

  const PickPlaylistDialog._({required this.playlists});

  /// Mostra o diálogo e retorna o ID da playlist escolhida, ou null se o
  /// usuário cancelar.
  static Future<int?> show(
    BuildContext context, {
    required List<Playlist> playlists,
  }) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => PickPlaylistDialog._(playlists: playlists),
    );

    if (result is int) return result;
    if (result is String) {
      final newPlaylist = await PlaylistDatabase.instance.createPlaylist(
        result,
      );
      return newPlaylist.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Adicionar à playlist'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: colorScheme.primary,
              ),
              title: const Text('Nova playlist'),
              onTap: () async {
                final controller = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Nome da playlist'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Nome'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        child: const Text('Criar'),
                      ),
                    ],
                  ),
                );
                if (name != null && name.isNotEmpty && context.mounted) {
                  Navigator.pop(context, name);
                }
              },
            ),
            if (playlists.isNotEmpty) const Divider(),
            ...playlists.map(
              (p) => ListTile(
                leading: const Icon(Icons.library_music_outlined),
                title: Text(p.name),
                subtitle: Text(
                  '${p.trackIds.length} música${p.trackIds.length == 1 ? '' : 's'}',
                ),
                onTap: () => Navigator.pop(context, p.id),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
