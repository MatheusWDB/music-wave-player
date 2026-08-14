import 'dart:io';

import 'package:flutter/material.dart';

/// Item de lista para telas de agrupamento (álbuns, artistas): ícone ou
/// capa à esquerda, título em destaque, subtítulo e seta indicando navegação.
class GroupedEntityTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const GroupedEntityTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.0),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

/// Avatar circular usado como [leading] em [GroupedEntityTile] para
/// artistas (sem capa de imagem).
class EntityAvatarIcon extends StatelessWidget {
  final IconData icon;

  const EntityAvatarIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(icon, color: colorScheme.onPrimaryContainer),
    );
  }
}

/// Miniatura quadrada usada como [leading] em [GroupedEntityTile] para
/// álbuns (com capa, se disponível).
class EntityCoverThumbnail extends StatelessWidget {
  final String? coverPath;
  final IconData fallbackIcon;

  const EntityCoverThumbnail({
    super.key,
    required this.coverPath,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 44,
        height: 44,
        child: coverPath != null
            ? Image.file(
                File(coverPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _Placeholder(icon: fallbackIcon, colorScheme: colorScheme),
              )
            : _Placeholder(icon: fallbackIcon, colorScheme: colorScheme),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final ColorScheme colorScheme;

  const _Placeholder({required this.icon, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.primaryContainer,
      child: Icon(icon, color: colorScheme.onPrimaryContainer),
    );
  }
}
