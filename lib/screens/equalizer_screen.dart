import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:provider/provider.dart';

class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

  Future<void> _confirmReset(BuildContext context) async {
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
    if (confirmed == true && context.mounted) {
      await context.read<Configuration>().resetEqualizer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.watch<Configuration>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restaurar',
            onPressed: () => _confirmReset(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Equalizador ativado'),
              value: config.eqEnabled,
              onChanged: (v) => context.read<Configuration>().setEqEnabled(v),
              activeColor: colorScheme.primary,
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _PresetSelector(config: config),
            const SizedBox(height: 16),
            Expanded(
              child: Opacity(
                opacity: config.eqEnabled ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !config.eqEnabled,
                  child: _BandsRow(config: config),
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

class _PresetSelector extends StatelessWidget {
  final Configuration config;
  const _PresetSelector({required this.config});

  @override
  Widget build(BuildContext context) {
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
          if (config.eqActivePreset == EqualizerPreset.manual)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Manual'),
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ...selectablePresets.map((preset) {
            final isSelected = config.eqActivePreset == preset;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(preset.label),
                selected: isSelected,
                onSelected: (_) =>
                    context.read<Configuration>().setEqPreset(preset),
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

class _BandsRow extends StatelessWidget {
  final Configuration config;
  const _BandsRow({required this.config});

  @override
  Widget build(BuildContext context) {
    final bands = config.eqBandDefinitions;
    final gains = config.eqBandGains;
    final configReader = context.read<Configuration>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(bands.length, (index) {
        return Expanded(
          child: _BandSlider(
            label: bands[index].label,
            gain: gains[index],
            minGain: config.eqMinGain,
            maxGain: config.eqMaxGain,
            flatGain: config.eqFlatGain,
            // Durante o arraste: só preview (memória + throttle no áudio).
            onChanged: (v) => configReader.previewEqBandGain(index, v),
            // Ao soltar: persiste e garante o valor final aplicado.
            onChangeEnd: (v) => configReader.setEqBandGain(index, v),
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
