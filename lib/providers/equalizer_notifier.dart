import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_wave_player/providers/music_audio_handler_provider.dart';
import 'package:music_wave_player/services/equalizer_service.dart';

export 'package:music_wave_player/services/equalizer_service.dart'
    show EqualizerBand, EqualizerPreset, EqualizerPresetLabel;

part 'equalizer_notifier.g.dart';

const String _kEqEnabledKey = 'eq_enabled';
const String _kEqPresetKey = 'eq_preset';
const String _kEqBandsKeyPrefix = 'eq_band_';

/// Ganhos prontos para cada preset — mesmos valores do antigo
/// [EqualizerService], agora públicos aqui para uso pelo Notifier.
const Map<EqualizerPreset, List<double>> _presetGains = {
  EqualizerPreset.normal: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  EqualizerPreset.rock: [1.4, 1.3, 1.1, 1.0, 0.9, 1.0, 1.1, 1.2, 1.3, 1.3],
  EqualizerPreset.pop: [0.95, 1.0, 1.15, 1.25, 1.2, 1.05, 1.0, 1.0, 1.05, 1.1],
  EqualizerPreset.jazz: [1.2, 1.15, 1.05, 1.1, 0.95, 0.95, 1.0, 1.1, 1.15, 1.2],
  EqualizerPreset.electronic: [
    1.4,
    1.3,
    1.1,
    1.0,
    0.9,
    1.0,
    1.05,
    1.1,
    1.3,
    1.35,
  ],
  EqualizerPreset.bassBoost: [1.6, 1.5, 1.3, 1.1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
  EqualizerPreset.trebleBoost: [
    1.0,
    1.0,
    1.0,
    1.0,
    1.0,
    1.0,
    1.1,
    1.3,
    1.5,
    1.6,
  ],
  EqualizerPreset.vocal: [
    0.9,
    0.95,
    1.0,
    1.1,
    1.25,
    1.25,
    1.15,
    1.05,
    1.0,
    0.95,
  ],
};

/// Estado imutável do equalizador gráfico.
class EqualizerState {
  final bool enabled;
  final EqualizerPreset activePreset;
  final List<double> bandGains;

  const EqualizerState({
    required this.enabled,
    required this.activePreset,
    required this.bandGains,
  });

  EqualizerState copyWith({
    bool? enabled,
    EqualizerPreset? activePreset,
    List<double>? bandGains,
  }) {
    return EqualizerState(
      enabled: enabled ?? this.enabled,
      activePreset: activePreset ?? this.activePreset,
      bandGains: bandGains ?? this.bandGains,
    );
  }

  /// Monta o mapa de parâmetros no formato esperado pelo
  /// `SuperequalizerSettings.params` do mpv_audio_kit.
  Map<String, double> get superequalizerParams => {
    for (int i = 0; i < EqualizerService.bands.length; i++)
      EqualizerService.bands[i].key: bandGains[i],
  };
}

/// Gerencia o estado do equalizador gráfico: 10 bandas, presets prontos e
/// persistência em [SharedPreferences]. Substitui o antigo [EqualizerService].
@Riverpod(keepAlive: true)
class EqualizerNotifier extends _$EqualizerNotifier {
  Timer? _throttleTimer;
  bool _applyPending = false;

  @override
  Future<EqualizerState> build() async {
    ref.onDispose(() => _throttleTimer?.cancel());
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kEqEnabledKey) ?? false;

    final presetKey = prefs.getString(_kEqPresetKey);
    final activePreset = EqualizerPreset.values.firstWhere(
      (p) => p.name == presetKey,
      orElse: () => EqualizerPreset.normal,
    );

    final bandGains = List.generate(
      EqualizerService.bands.length,
      (i) =>
          prefs.getDouble('$_kEqBandsKeyPrefix$i') ?? EqualizerService.flatGain,
    );

    return EqualizerState(
      enabled: enabled,
      activePreset: activePreset,
      bandGains: bandGains,
    );
  }

  Future<void> setEnabled(bool value) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.copyWith(enabled: value);
    state = AsyncData(updated);
    await _applyToAudio(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEqEnabledKey, value);
  }

  Future<void> setPreset(EqualizerPreset preset) async {
    if (preset == EqualizerPreset.manual) return;
    final current = state.valueOrNull;
    if (current == null) return;
    final gains = List.of(
      _presetGains[preset] ??
          List.filled(EqualizerService.bands.length, EqualizerService.flatGain),
    );
    final updated = current.copyWith(activePreset: preset, bandGains: gains);
    state = AsyncData(updated);
    await _applyToAudio(updated);
    await _persistPresetAndBands();
  }

  /// Ajusta uma banda manualmente e persiste. Muda o preset ativo para
  /// [EqualizerPreset.manual]. Chamado ao soltar o slider (onChangeEnd).
  Future<void> setBandGain(int index, double gain) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (index < 0 || index >= current.bandGains.length) return;

    _throttleTimer?.cancel();
    _throttleTimer = null;
    _applyPending = false;

    final gains = List.of(current.bandGains);
    gains[index] = gain.clamp(
      EqualizerService.minGain,
      EqualizerService.maxGain,
    );
    final updated = current.copyWith(
      activePreset: EqualizerPreset.manual,
      bandGains: gains,
    );
    state = AsyncData(updated);
    await _applyToAudio(updated);
    await _persistPresetAndBands();
  }

  /// Atualiza o ganho apenas em memória, sem persistir em disco. Usado
  /// durante o arraste do slider — a persistência ocorre só em
  /// [setBandGain], chamado ao soltar o dedo. A aplicação no áudio é
  /// limitada (throttle leading+trailing) para não reconfigurar a cadeia
  /// de filtros do ffmpeg a cada frame do arraste.
  void previewBandGain(int index, double gain) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (index < 0 || index >= current.bandGains.length) return;

    final gains = List.of(current.bandGains);
    gains[index] = gain.clamp(
      EqualizerService.minGain,
      EqualizerService.maxGain,
    );
    final updated = current.copyWith(
      activePreset: EqualizerPreset.manual,
      bandGains: gains,
    );
    state = AsyncData(updated);
    _throttledApplyToAudio();
  }

  Future<void> reset() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.copyWith(
      activePreset: EqualizerPreset.normal,
      bandGains: List.filled(
        EqualizerService.bands.length,
        EqualizerService.flatGain,
      ),
    );
    state = AsyncData(updated);
    await _applyToAudio(updated);
    await _persistPresetAndBands();
  }

  Future<void> _applyToAudio(EqualizerState eqState) async {
    await ref
        .read(musicAudioHandlerProvider)
        .applyEqualizer(eqState.enabled, eqState.superequalizerParams);
  }

  /// Throttle leading+trailing: aplica imediatamente na primeira chamada,
  /// depois no máximo uma vez a cada 120ms, garantindo que o último valor
  /// arrastado sempre seja aplicado ao final (chamada trailing).
  void _throttledApplyToAudio() {
    if (_throttleTimer != null) {
      _applyPending = true;
      return;
    }
    final current = state.valueOrNull;
    if (current != null) _applyToAudio(current);

    _throttleTimer = Timer(const Duration(milliseconds: 120), () {
      _throttleTimer = null;
      if (_applyPending) {
        _applyPending = false;
        _throttledApplyToAudio();
      }
    });
  }

  Future<void> _persistPresetAndBands() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEqPresetKey, current.activePreset.name);
    for (int i = 0; i < current.bandGains.length; i++) {
      await prefs.setDouble('$_kEqBandsKeyPrefix$i', current.bandGains[i]);
    }
  }
}
