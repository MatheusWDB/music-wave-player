import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:provider/provider.dart';

/// Slider de progresso de reprodução com interpolação suave entre
/// atualizações de posição (que chegam a cada poucos frames do player,
/// não a 60fps) — usa um [AnimationController] como ticker para
/// avançar visualmente a posição entre atualizações reais.
class SmoothProgressSlider extends StatefulWidget {
  final double? draggingValue;
  final ValueChanged<double> onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  const SmoothProgressSlider({
    super.key,
    required this.draggingValue,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<SmoothProgressSlider> createState() => _SmoothProgressSliderState();
}

class _SmoothProgressSliderState extends State<SmoothProgressSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  double _smoothPosition = 0.0;
  DateTime? _lastTickTime;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    );
    _ticker.addListener(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    final config = context.read<Configuration>();
    if (widget.draggingValue != null || !config.isPlaying) return;
    final now = DateTime.now();
    final elapsed = _lastTickTime != null
        ? now.difference(_lastTickTime!).inMilliseconds
        : 16;
    _lastTickTime = now;
    final realPosition = config.currentPositionMs.toDouble();
    final diff = (realPosition - _smoothPosition).abs();
    if (diff > 1500) {
      _smoothPosition = realPosition;
    } else {
      _smoothPosition += elapsed;
      _smoothPosition += (realPosition - _smoothPosition) * 0.05;
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _smoothPosition = context
        .read<Configuration>()
        .currentPositionMs
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = context.select<Configuration, bool>((c) => c.isPlaying);
    final positionMs = context.select<Configuration, int>(
      (c) => c.currentPositionMs,
    );
    final durationMs = context.select<Configuration, int>(
      (c) => c.trackDurationMs,
    );
    final colorScheme = Theme.of(context).colorScheme;

    if (isPlaying && !_ticker.isAnimating) {
      _lastTickTime = DateTime.now();
      _ticker.forward();
    } else if (!isPlaying && _ticker.isAnimating) {
      _ticker.stop();
      _smoothPosition = positionMs.toDouble();
    }

    final double max = durationMs > 0 ? durationMs.toDouble() : 1.0;
    final double displayValue =
        widget.draggingValue ?? _smoothPosition.clamp(0.0, max);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.primary.withValues(alpha: 0.25),
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            trackHeight: 3.5,
          ),
          child: Slider(
            min: 0.0,
            max: max,
            value: displayValue.clamp(0.0, max),
            onChanged: (v) {
              if (widget.draggingValue == null) {
                widget.onDragStart(v);
              } else {
                widget.onDragUpdate(v);
              }
            },
            onChangeEnd: widget.onDragEnd,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt((widget.draggingValue ?? _smoothPosition).toInt()),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Text(
                _fmt(durationMs),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms < 0 ? 0 : ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}
