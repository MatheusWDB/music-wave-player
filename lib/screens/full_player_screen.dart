import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/edit_track_bottom_sheet.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:provider/provider.dart';

class FullPlayerScreen extends StatefulWidget {
  final int? initialTrackId;
  const FullPlayerScreen({super.key, this.initialTrackId});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen>
    with SingleTickerProviderStateMixin {
  double? _draggingValue;

  @override
  Widget build(BuildContext context) {
    final currentTrack = context.select<Configuration, MusicTrack?>(
      (c) => c.currentTrack,
    );
    final isPlaying = context.select<Configuration, bool>((c) => c.isPlaying);
    final isShuffleActive = context.select<Configuration, bool>(
      (c) => c.isShuffleActive,
    );
    final repeatMode = context.select<Configuration, String>(
      (c) => c.repeatMode,
    );
    final config = context.read<Configuration>();
    final colorScheme = Theme.of(context).colorScheme;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (currentTrack == null) {
      if (widget.initialTrackId != null &&
          config.lastPlayedMusicId != widget.initialTrackId) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => config.playTrack(widget.initialTrackId!),
        );
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Player')),
        body: const Center(child: Text('Nenhuma faixa selecionada.')),
      );
    }

    final coverWidget = CoverArtWidget(
      coverPath: currentTrack.coverPath,
      size: double.infinity,
      borderRadius: BorderRadius.circular(20),
    );

    final trackInfo = _TrackInfo(
      title: currentTrack.title,
      artist: currentTrack.artist,
      album: currentTrack.album,
      colorScheme: colorScheme,
    );

    final slider = _SmoothProgressSlider(
      draggingValue: _draggingValue,
      onDragStart: (v) => setState(() => _draggingValue = v),
      onDragUpdate: (v) => setState(() => _draggingValue = v),
      onDragEnd: (v) {
        config.seekTo(v.toInt());
        setState(() => _draggingValue = null);
      },
    );

    final controls = _Controls(
      isPlaying: isPlaying,
      isShuffleActive: isShuffleActive,
      repeatMode: repeatMode,
      config: config,
      colorScheme: colorScheme,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: const Text('LocalPlay'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                EditTrackBottomSheet.show(context, track: currentTrack);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 12),
                    Text('Editar informações'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: isLandscape
            ? _LandscapeLayout(
                coverWidget: coverWidget,
                trackInfo: trackInfo,
                slider: slider,
                controls: controls,
                colorScheme: colorScheme,
              )
            : _PortraitLayout(
                coverWidget: coverWidget,
                trackInfo: trackInfo,
                slider: slider,
                controls: controls,
                colorScheme: colorScheme,
              ),
      ),
    );
  }
}

// ── Layouts ───────────────────────────────────────────────────────────────────

class _PortraitLayout extends StatelessWidget {
  final Widget coverWidget, trackInfo, slider, controls;
  final ColorScheme colorScheme;
  const _PortraitLayout({
    required this.coverWidget,
    required this.trackInfo,
    required this.slider,
    required this.controls,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 320),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24.0),
              child: coverWidget,
            ),
          ),
          trackInfo,
          const SizedBox(height: 20),
          slider,
          const SizedBox(height: 16),
          controls,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LandscapeLayout extends StatelessWidget {
  final Widget coverWidget, trackInfo, slider, controls;
  final ColorScheme colorScheme;
  const _LandscapeLayout({
    required this.coverWidget,
    required this.trackInfo,
    required this.slider,
    required this.controls,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: coverWidget,
          ),
        ),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 16, 24, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                trackInfo,
                const SizedBox(height: 16),
                slider,
                const SizedBox(height: 8),
                controls,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Slider suave ──────────────────────────────────────────────────────────────

class _SmoothProgressSlider extends StatefulWidget {
  final double? draggingValue;
  final ValueChanged<double> onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  const _SmoothProgressSlider({
    required this.draggingValue,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<_SmoothProgressSlider> createState() => _SmoothProgressSliderState();
}

class _SmoothProgressSliderState extends State<_SmoothProgressSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  double _smoothPosition = 0.0;

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

  DateTime? _lastTickTime;

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

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _TrackInfo extends StatelessWidget {
  final String title, artist, album;
  final ColorScheme colorScheme;
  const _TrackInfo({
    required this.title,
    required this.artist,
    required this.album,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          artist,
          style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          album,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  final bool isPlaying, isShuffleActive;
  final String repeatMode;
  final Configuration config;
  final ColorScheme colorScheme;
  const _Controls({
    required this.isPlaying,
    required this.isShuffleActive,
    required this.repeatMode,
    required this.config,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle,
            color: isShuffleActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          iconSize: 26,
          onPressed: config.toggleShuffle,
        ),
        IconButton(
          icon: Icon(Icons.skip_previous, color: colorScheme.primary),
          iconSize: 44,
          onPressed: config.playPreviousTrack,
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: colorScheme.onPrimary,
            ),
            iconSize: 38,
            padding: const EdgeInsets.all(10),
            onPressed: config.togglePlayPause,
          ),
        ),
        IconButton(
          icon: Icon(Icons.skip_next, color: colorScheme.primary),
          iconSize: 44,
          onPressed: config.playNextTrack,
        ),
        IconButton(
          icon: Icon(
            repeatMode == 'One' ? Icons.repeat_one : Icons.repeat,
            color: repeatMode == 'Off'
                ? colorScheme.onSurfaceVariant
                : colorScheme.primary,
          ),
          iconSize: 26,
          onPressed: config.toggleRepeatMode,
        ),
      ],
    );
  }
}
