import 'package:flutter/material.dart';
import 'package:music_wave_player/components/rank_badge.dart';

/// Item de lista simples para a tela de estatísticas: posição, título,
/// subtítulo opcional e tempo ouvido formatado. Diferente de
/// [RankedTrackTile], não exibe duração da faixa nem selo de "nunca ouvida"
/// — a tela de estatísticas só lista itens que já tiveram reprodução.
class StatRankTile extends StatelessWidget {
  final int position;
  final String title;
  final String? subtitle;
  final String timeLabel;

  const StatRankTile({
    super.key,
    required this.position,
    required this.title,
    this.subtitle,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: RankBadge(position: position),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            )
          : null,
      trailing: Text(
        timeLabel,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
