import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/draggable_sheet_scaffold.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/services/favorites_service.dart';

/// Bottom sheet de ações rápidas para uma música (favoritar, editar,
/// avaliar, fila, playlist, ocultar). Substitui o antigo menu suspenso (⋮)
/// por um visual mais parecido com apps de música consolidados, com a capa
/// e o título/artista da faixa no cabeçalho.
class TrackOptionsBottomSheet extends StatefulWidget {
  final MusicTrack track;
  final VoidCallback onEdit;
  final VoidCallback onRate;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onInsertNext;
  final VoidCallback onAddToEnd;
  final VoidCallback onHide;

  const TrackOptionsBottomSheet._({
    required this.track,
    required this.onEdit,
    required this.onRate,
    required this.onAddToPlaylist,
    required this.onInsertNext,
    required this.onAddToEnd,
    required this.onHide,
  });

  static void show(
    BuildContext context, {
    required MusicTrack track,
    required VoidCallback onEdit,
    required VoidCallback onRate,
    required VoidCallback onAddToPlaylist,
    required VoidCallback onInsertNext,
    required VoidCallback onAddToEnd,
    required VoidCallback onHide,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrackOptionsBottomSheet._(
        track: track,
        onEdit: onEdit,
        onRate: onRate,
        onAddToPlaylist: onAddToPlaylist,
        onInsertNext: onInsertNext,
        onAddToEnd: onAddToEnd,
        onHide: onHide,
      ),
    );
  }

  @override
  State<TrackOptionsBottomSheet> createState() =>
      _TrackOptionsBottomSheetState();
}

class _TrackOptionsBottomSheetState extends State<TrackOptionsBottomSheet> {
  bool _isFavorite = false;
  bool _loadingFavorite = true;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final isFav = await FavoritesService.isFavorite(widget.track.id!);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _loadingFavorite = false;
      });
    }
  }

  // Fecha o sheet e só então dispara a ação, para a tela por trás não
  // reconstruir com o sheet ainda meio-aberto.
  void _select(VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  void _toggleFavorite() {
    FavoritesService.toggle(widget.track.id!);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final track = widget.track;

    return DraggableSheetScaffold(
      title: 'Opções da música',
      initialSize: 0.5,
      minSize: 0.35,
      maxSize: 0.85,
      header: Row(
        children: [
          CoverArtWidget(
            coverPath: track.coverPath,
            size: 44,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bodyBuilder: (context, scrollController) {
        final items = <_TrackOption>[
          _TrackOption(
            icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
            label: _isFavorite ? 'Remover dos favoritos' : 'Favoritar',
            iconColor: _isFavorite ? colorScheme.error : null,
            onTap: _loadingFavorite ? null : _toggleFavorite,
          ),
          _TrackOption(
            icon: Icons.queue_play_next_outlined,
            label: 'Tocar a seguir',
            onTap: () => _select(widget.onInsertNext),
          ),
          _TrackOption(
            icon: Icons.add_to_queue_outlined,
            label: 'Adicionar à fila',
            onTap: () => _select(widget.onAddToEnd),
          ),
          _TrackOption(
            icon: Icons.playlist_add_outlined,
            label: 'Adicionar à playlist',
            onTap: () => _select(widget.onAddToPlaylist),
          ),
          _TrackOption(
            icon: Icons.edit_outlined,
            label: 'Editar informações',
            onTap: () => _select(widget.onEdit),
          ),
          _TrackOption(
            icon: Icons.star_outline,
            label: 'Avaliar',
            onTap: () => _select(widget.onRate),
          ),
          _TrackOption(
            icon: Icons.visibility_off_outlined,
            label: 'Ocultar',
            onTap: () => _select(widget.onHide),
          ),
        ];

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: Icon(
                item.icon,
                color: item.iconColor ?? colorScheme.onSurfaceVariant,
              ),
              title: Text(item.label),
              onTap: item.onTap,
            );
          },
        );
      },
    );
  }
}

class _TrackOption {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _TrackOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });
}
