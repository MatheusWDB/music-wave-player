import 'package:flutter/material.dart';
import 'package:music_wave_player/services/favorites_service.dart';

/// Botão de coração que adiciona/remove a faixa dos Favoritos.
/// Gerencia seu próprio estado assíncrono.
class FavoriteButton extends StatefulWidget {
  final int trackId;
  final double iconSize;
  final Color? activeColor;

  const FavoriteButton({
    super.key,
    required this.trackId,
    this.iconSize = 24,
    this.activeColor,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _isFavorite = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final isFav = await FavoritesService.isFavorite(widget.trackId);
    if (mounted)
      setState(() {
        _isFavorite = isFav;
        _loading = false;
      });
  }

  Future<void> _toggle() async {
    // Atualização otimista
    setState(() => _isFavorite = !_isFavorite);
    await FavoritesService.toggle(widget.trackId);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? Theme.of(context).colorScheme.error;
    return IconButton(
      iconSize: widget.iconSize,
      onPressed: _loading ? null : _toggle,
      icon: Icon(
        _isFavorite ? Icons.favorite : Icons.favorite_border,
        color: _isFavorite ? color : null,
      ),
    );
  }
}
