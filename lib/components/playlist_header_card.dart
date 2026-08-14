import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';

/// Cabeçalho da tela de detalhe de playlist: capa (da primeira faixa com
/// capa disponível), nome, contagem de músicas, duração total e botão
/// "Tocar".
class PlaylistHeaderCard extends StatelessWidget {
  final String name;
  final String? coverPath;
  final int trackCount;
  final String durationLabel;
  final VoidCallback? onPlay;

  const PlaylistHeaderCard({
    super.key,
    required this.name,
    required this.coverPath,
    required this.trackCount,
    required this.durationLabel,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
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
          ),
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
          if (onPlay != null)
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Tocar'),
            ),
        ],
      ),
    );
  }
}
