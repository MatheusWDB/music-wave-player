import 'package:flutter/material.dart';

/// Item de lista usado nas páginas de top músicas/artistas do recap.
/// Os 3 primeiros lugares recebem destaque visual maior.
class RecapListTile extends StatelessWidget {
  final int position;
  final String title;
  final String? subtitle;
  final String time;
  final bool isTop3;

  const RecapListTile({
    super.key,
    required this.position,
    required this.title,
    this.subtitle,
    required this.time,
    required this.isTop3,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$position',
              style: TextStyle(
                color: isTop3 ? const Color(0xFFA8DADC) : Colors.white38,
                fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
                fontSize: isTop3 ? 16 : 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isTop3 ? FontWeight.w600 : FontWeight.normal,
                    fontSize: isTop3 ? 15 : 13,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: const TextStyle(
              color: Color(0xFFA8DADC),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
