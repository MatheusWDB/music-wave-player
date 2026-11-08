import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/editable_image_frame.dart';

/// Cabeçalho da tela de detalhe de playlist: capa (imagem personalizada ou
/// da primeira faixa com capa disponível), nome, contagem de músicas,
/// duração total e botão de play. [onCoverTap] abre a edição da imagem.
class PlaylistHeaderCard extends StatelessWidget {
  final String name;
  final String? coverPath;
  final int trackCount;
  final String durationLabel;
  final Widget? playButton;
  final VoidCallback? onCoverTap;

  const PlaylistHeaderCard({
    super.key,
    required this.name,
    required this.coverPath,
    required this.trackCount,
    required this.durationLabel,
    required this.playButton,
    this.onCoverTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final cover = Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: coverPath != null
          ? CoverArtWidget(
              coverPath: coverPath,
              size: 80,
              borderRadius: BorderRadius.circular(12),
            )
          : Icon(
              Icons.library_music,
              size: 40,
              color: colorScheme.onPrimaryContainer,
            ),
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          onCoverTap != null
              ? EditableImageFrame(onTap: onCoverTap!, child: cover)
              : cover,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$trackCount música${trackCount == 1 ? '' : 's'} · $durationLabel',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (playButton != null) playButton!,
        ],
      ),
    );
  }
}
