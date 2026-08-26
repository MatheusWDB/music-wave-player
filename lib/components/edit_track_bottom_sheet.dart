import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/pick_playlist_dialog.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';

class EditTrackBottomSheet extends ConsumerStatefulWidget {
  final MusicTrack track;

  const EditTrackBottomSheet._({required this.track});

  static Future<bool> show(
    BuildContext context, {
    required MusicTrack track,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditTrackBottomSheet._(track: track),
    );
    return result ?? false;
  }

  @override
  ConsumerState<EditTrackBottomSheet> createState() =>
      _EditTrackBottomSheetState();
}

class _EditTrackBottomSheetState extends ConsumerState<EditTrackBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _albumCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.track.title);
    _artistCtrl = TextEditingController(text: widget.track.artist);
    _albumCtrl = TextEditingController(text: widget.track.album);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final result = await ref
        .read(indexingNotifierProvider.notifier)
        .editTrack(
          track: widget.track,
          newTitle: _titleCtrl.text.trim(),
          newArtist: _artistCtrl.text.trim(),
          newAlbum: _albumCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    switch (result) {
      case TrackEditSuccess():
        _showSnack('Informações salvas com sucesso!', isSuccess: true);
        Navigator.of(context).pop(true);
      case TrackEditFailure(:final reason):
        _showSnack(reason);
    }
  }

  Future<void> _addToPlaylist() async {
    final playlists = await PlaylistDatabase.instance.readAllPlaylists();
    if (!mounted) return;

    final playlistId = await PickPlaylistDialog.show(
      context,
      playlists: playlists,
    );
    if (playlistId == null) return;

    await PlaylistDatabase.instance.addTracks(playlistId, [widget.track.id!]);
    _showSnack('Música adicionada à playlist!', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Editar informações',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.track.path.split('/').last,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Botão adicionar à playlist
                IconButton(
                  onPressed: _addToPlaylist,
                  icon: const Icon(Icons.playlist_add_outlined),
                  tooltip: 'Adicionar à playlist',
                  color: colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _Field(
                    controller: _titleCtrl,
                    label: 'Título',
                    icon: Icons.music_note_outlined,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    controller: _artistCtrl,
                    label: 'Artista',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    controller: _albumCtrl,
                    label: 'Álbum',
                    icon: Icons.album_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
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
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
    );
  }
}
