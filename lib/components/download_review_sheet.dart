import 'dart:io';

import 'package:flutter/material.dart';
import 'package:music_wave_player/services/download_service.dart';

/// Bottom sheet para conferir e ajustar título, artista e álbum de uma
/// música recém-baixada, antes de ela ser gravada na biblioteca.
/// Retorna as tags confirmadas, ou null se o usuário cancelar.
class DownloadReviewSheet extends StatefulWidget {
  final DownloadTags initial;
  final String? coverPath;

  /// Diz se já existe na biblioteca uma faixa com esse título e artista.
  final bool Function(String title, String artist)? isDuplicate;

  const DownloadReviewSheet._({
    required this.initial,
    this.coverPath,
    this.isDuplicate,
  });

  static Future<DownloadTags?> show(
    BuildContext context, {
    required DownloadTags initial,
    String? coverPath,
    bool Function(String title, String artist)? isDuplicate,
  }) {
    return showModalBottomSheet<DownloadTags>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DownloadReviewSheet._(
        initial: initial,
        coverPath: coverPath,
        isDuplicate: isDuplicate,
      ),
    );
  }

  @override
  State<DownloadReviewSheet> createState() => _DownloadReviewSheetState();
}

class _DownloadReviewSheetState extends State<DownloadReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _albumCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initial.title);
    _artistCtrl = TextEditingController(text: widget.initial.artist);
    _albumCtrl = TextEditingController(text: widget.initial.album);
    // Reavalia o aviso de duplicata enquanto o usuário edita.
    _titleCtrl.addListener(_refresh);
    _artistCtrl.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  bool get _isDuplicate =>
      widget.isDuplicate?.call(_titleCtrl.text, _artistCtrl.text) ?? false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      DownloadTags(
        title: _titleCtrl.text.trim(),
        artist: _artistCtrl.text.trim(),
        album: _albumCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom + media.padding.bottom;

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SingleChildScrollView(
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
                _CoverPreview(path: widget.coverPath),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revisar informações',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'As tags são gravadas direto no arquivo.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
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
                    helper: 'Separe vários artistas com ;',
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    controller: _albumCtrl,
                    label: 'Álbum',
                    icon: Icons.album_outlined,
                  ),
                  if (_isDuplicate) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Já existe uma faixa com esse título e artista na biblioteca.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
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
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_isDuplicate ? 'Salvar mesmo assim' : 'Salvar'),
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

class _CoverPreview extends StatelessWidget {
  final String? path;

  const _CoverPreview({required this.path});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        height: 64,
        child: path != null
            ? Image.file(
                File(path!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(colorScheme),
              )
            : _placeholder(colorScheme),
      ),
    );
  }

  Widget _placeholder(ColorScheme colorScheme) => ColoredBox(
    color: colorScheme.surfaceContainerHighest,
    child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? helper;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.helper,
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
        helperText: helper,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
    );
  }
}