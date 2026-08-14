import 'package:flutter/material.dart';
import 'package:music_wave_player/components/listening_stats_section.dart';
import 'package:music_wave_player/components/rank_badge.dart';

/// Item de lista para rankings de reprodução (mais/menos ouvidas,
/// estatísticas), mostrando posição, título, artista, tempo ouvido e
/// duração da faixa. Exibe um selo "Nunca ouvida" quando [seconds] é 0.
class RankedTrackTile extends StatelessWidget {
  final int position;
  final String title;
  final String artist;
  final int seconds;
  final int durationMs;
  final VoidCallback onTap;

  const RankedTrackTile({
    super.key,
    required this.position,
    required this.title,
    required this.artist,
    required this.seconds,
    required this.durationMs,
    required this.onTap,
  });

  static String _formatDuration(int totalMs) {
    final d = Duration(milliseconds: totalMs);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
    if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPlays = seconds > 0;

    return ListTile(
      leading: RankBadge(position: position),
      title: Row(
        children: [
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (!hasPlays)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Nunca ouvida',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (hasPlays)
            Text(
              ListeningStatsSection.formatSeconds(seconds),
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          Text(
            _formatDuration(durationMs),
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
