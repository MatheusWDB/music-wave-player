import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/providers/equalizer_notifier.dart';
import 'package:music_wave_player/services/equalizer_service.dart';

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar equalizador'),
        content: const Text(
          'Isso vai zerar todas as bandas e voltar ao preset Normal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(equalizerNotifierProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final eqState = ref.watch(equalizerNotifierProvider).valueOrNull;

    if (eqState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restaurar',
            onPressed: () => _confirmReset(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Equalizador ativado'),
              value: eqState.enabled,
              onChanged: (v) =>
                  ref.read(equalizerNotifierProvider.notifier).setEnabled(v),
              activeColor: colorScheme.primary,
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _PresetSelector(activePreset: eqState.activePreset),
            const SizedBox(height: 16),
            Expanded(
              child: Opacity(
                opacity: eqState.enabled ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !eqState.enabled,
                  child: _BandsRow(bandGains: eqState.bandGains),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PresetSelector extends ConsumerWidget {
  final EqualizerPreset activePreset;
  const _PresetSelector({required this.activePreset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // "Manual" não aparece como opção selecionável — é um estado resultante
    // de ajuste manual das bandas, exibido apenas como rótulo informativo.
    final selectablePresets = EqualizerPreset.values
        .where((p) => p != EqualizerPreset.manual)
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (activePreset == EqualizerPreset.manual)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Manual'),
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ...selectablePresets.map((preset) {
            final isSelected = activePreset == preset;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(preset.label),
                selected: isSelected,
                onSelected: (_) => ref
                    .read(equalizerNotifierProvider.notifier)
                    .setPreset(preset),
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

class _BandsRow extends ConsumerWidget {
  final List<double> bandGains;
  const _BandsRow({required this.bandGains});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bands = EqualizerService.bands;
    final notifier = ref.read(equalizerNotifierProvider.notifier);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(bands.length, (index) {
        return Expanded(
          child: _BandSlider(
            label: bands[index].label,
            gain: bandGains[index],
            minGain: EqualizerService.minGain,
            maxGain: EqualizerService.maxGain,
            flatGain: EqualizerService.flatGain,
            // Durante o arraste: só preview (memória + throttle no áudio).
            onChanged: (v) => notifier.previewBandGain(index, v),
            // Ao soltar: persiste e garante o valor final aplicado.
            onChangeEnd: (v) => notifier.setBandGain(index, v),
          ),
        );
      }),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final String label;
  final double gain;
  final double minGain;
  final double maxGain;
  final double flatGain;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _BandSlider({
    required this.label,
    required this.gain,
    required this.minGain,
    required this.maxGain,
    required this.flatGain,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Converte o ganho linear (0.0–2.0) em um percentual relativo ao
    // ponto neutro (1.0), só para exibição amigável ao usuário.
    final percentLabel = '${((gain - flatGain) * 100).round()}%';

    return Column(
      children: [
        Text(
          percentLabel,
          style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                min: minGain,
                max: maxGain,
                value: gain.clamp(minGain, maxGain),
                activeColor: colorScheme.primary,
                inactiveColor: colorScheme.primary.withValues(alpha: 0.2),
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
