import 'package:flutter/material.dart';
import 'package:music_wave_player/theme/app_colors.dart';

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

const List<_NavItem> _items = [
  _NavItem(Icons.music_note_outlined, 'Músicas'),
  _NavItem(Icons.library_music_outlined, 'Playlists'),
  _NavItem(Icons.person_outlined, 'Artistas'),
  _NavItem(Icons.album_outlined, 'Álbuns'),
];

/// Barra de navegação inferior com os quatro destinos principais da
/// biblioteca (Músicas, Playlists, Artistas, Álbuns). Substitui o antigo
/// [TabBar] no topo — ícone em cima, label embaixo, com um pill animado
/// atrás do item selecionado.
class LibraryBottomNav extends StatelessWidget {
  const LibraryBottomNav({
    super.key,
    required this.activeIndex,
    required this.onTap,
  });

  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
      decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: 0.85)),
      child: Row(
        children: List.generate(_items.length, (index) {
          final bool selected = index == activeIndex;
          final item = _items[index];
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 22,
                      color: selected ? AppColors.bg : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? AppColors.bg
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
