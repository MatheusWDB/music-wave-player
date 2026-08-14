import 'package:flutter/material.dart';

enum StatsPeriod { lastMonth, lastQuarter, lastSemester, year }

/// Seção reutilizável de "tempo ouvido" com filtro de período (mês,
/// trimestre, semestre, ano) — usada nas telas de detalhe de álbum e artista.
///
/// Não mantém estado próprio: o chamador controla [selectedPeriod] /
/// [selectedYear] e recarrega os dados via [onPeriodSelected] / [onYearSelected].
class ListeningStatsSection extends StatelessWidget {
  final bool loading;
  final int totalSeconds;
  final StatsPeriod selectedPeriod;
  final int? selectedYear;
  final List<int> availableYears;
  final ValueChanged<StatsPeriod> onPeriodSelected;
  final ValueChanged<int> onYearSelected;

  const ListeningStatsSection({
    super.key,
    required this.loading,
    required this.totalSeconds,
    required this.selectedPeriod,
    required this.selectedYear,
    required this.availableYears,
    required this.onPeriodSelected,
    required this.onYearSelected,
  });

  static String formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem > 0 ? '${h}h ${rem}min' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.bar_chart_outlined,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tempo ouvido',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    totalSeconds > 0 ? formatSeconds(totalSeconds) : '—',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
          ),
          _FilterBar(
            selectedPeriod: selectedPeriod,
            selectedYear: selectedYear,
            availableYears: availableYears,
            onPeriodSelected: onPeriodSelected,
            onYearSelected: onYearSelected,
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final StatsPeriod selectedPeriod;
  final int? selectedYear;
  final List<int> availableYears;
  final ValueChanged<StatsPeriod> onPeriodSelected;
  final ValueChanged<int> onYearSelected;

  const _FilterBar({
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
