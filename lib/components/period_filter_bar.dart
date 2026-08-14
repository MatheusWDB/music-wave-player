import 'package:flutter/material.dart';
import 'package:music_wave_player/components/listening_stats_section.dart'
    show StatsPeriod;

/// Barra horizontal de chips para filtro de período (mês, trimestre,
/// semestre, anos disponíveis). Reutilizada em telas de estatísticas e
/// rankings de reprodução — usa o mesmo [StatsPeriod] de [ListeningStatsSection]
/// para manter o filtro consistente em todo o app.
class PeriodFilterBar extends StatelessWidget {
  final StatsPeriod selectedPeriod;
  final int? selectedYear;
  final List<int> availableYears;
  final ValueChanged<StatsPeriod> onPeriodSelected;
  final ValueChanged<int> onYearSelected;

  const PeriodFilterBar({
    super.key,
    required this.selectedPeriod,
    required this.selectedYear,
    required this.availableYears,
    required this.onPeriodSelected,
    required this.onYearSelected,
  });

  static const _periods = [
    (StatsPeriod.lastMonth, 'Último mês'),
    (StatsPeriod.lastQuarter, 'Trimestre'),
    (StatsPeriod.lastSemester, 'Semestre'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ..._periods.map((p) {
            final isSelected = selectedPeriod == p.$1 && selectedYear == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(p.$2),
                selected: isSelected,
                onSelected: (_) => onPeriodSelected(p.$1),
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.primary,
              ),
            );
          }),
          ...availableYears.map((year) {
            final isSelected = selectedYear == year;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('$year'),
                selected: isSelected,
                onSelected: (_) => onYearSelected(year),
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.primary,
              ),
            );
          }),
        ],
      ),
    );
  }
}
