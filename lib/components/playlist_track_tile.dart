import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/models/music_track.dart';

/// Item de lista de uma música dentro de uma playlist, com menu de ações
/// específico (remover da playlist, avaliar, ocultar).
class PlaylistTrackTile extends StatelessWidget {
  final MusicTrack track;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onRate;
  final VoidCallback onHide;

  const PlaylistTrackTile({
    super.key,
    required this.track,
    required this.onTap,
    required this.onRemove,
    required this.onRate,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CoverArtWidget(
        coverPath: track.coverPath,
        size: 44,
        borderRadius: BorderRadius.circular(6),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'remove':
              onRemove();
            case 'rate':
              onRate();
            case 'hide':
              onHide();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.remove_circle_outline),
                SizedBox(width: 12),
                Text('Remover da playlist'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'rate',
            child: Row(
              children: [
                Icon(Icons.star_outline),
                SizedBox(width: 12),
                Text('Avaliar'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'hide',
            child: Row(
              children: [
                Icon(Icons.visibility_off_outlined),
                SizedBox(width: 12),
                Text('Ocultar'),
              ],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
