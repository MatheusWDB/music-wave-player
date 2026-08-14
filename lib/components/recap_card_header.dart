import 'package:flutter/material.dart';

/// Cabeçalho do card de recap: ícone/rótulo do período e indicador de
/// páginas (dots) do carrossel de músicas/artistas.
class RecapCardHeader extends StatelessWidget {
  final String periodIcon;
  final String periodLabel;
  final int currentPage;
  final int pageCount;

  const RecapCardHeader({
    super.key,
    required this.periodIcon,
    required this.periodLabel,
    required this.currentPage,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        children: [
          Text(
            '$periodIcon Recap',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            periodLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: currentPage == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: currentPage == i
                      ? const Color(0xFFA8DADC)
                      : Colors.white30,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
