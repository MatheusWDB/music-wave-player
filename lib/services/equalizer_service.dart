import 'package:shared_preferences/shared_preferences.dart';

/// Uma banda do equalizador gráfico exibida na UI, mapeada para a banda
/// correspondente do filtro `superequalizer` do mpv (18 bandas ISO, chaves '1b'..'18b').
class EqualizerBand {
  final String label; // Rótulo exibido (ex: "62Hz")
  final String key; // Chave da banda no superequalizer (ex: "2b")

  const EqualizerBand({required this.label, required this.key});
}

enum EqualizerPreset {
  manual,
  normal,
  rock,
  pop,
  jazz,
  electronic,
  bassBoost,
  trebleBoost,
  vocal,
}

extension EqualizerPresetLabel on EqualizerPreset {
  String get label => switch (this) {
    EqualizerPreset.manual => 'Manual',
    EqualizerPreset.normal => 'Normal',
    EqualizerPreset.rock => 'Rock',
    EqualizerPreset.pop => 'Pop',
    EqualizerPreset.jazz => 'Jazz',
    EqualizerPreset.electronic => 'Eletrônica',
    EqualizerPreset.bassBoost => 'Reforço de graves',
    EqualizerPreset.trebleBoost => 'Reforço de agudos',
    EqualizerPreset.vocal => 'Voz',
  };
}

const String _kEqEnabledKey = 'eq_enabled';
const String _kEqPresetKey = 'eq_preset';
const String _kEqBandsKeyPrefix = 'eq_band_';

/// Gerencia o estado do equalizador gráfico: 10 bandas mapeadas para o
/// filtro `superequalizer` (18 bandas nativas do mpv), presets prontos e
/// persistência em [SharedPreferences].
///
/// Ganho de cada banda: multiplicador linear, onde 1.0 = neutro (0 dB),
/// 0.0 = banda mutada, 2.0 = dobro do volume da banda. Faixa de UI: 0.0–2.0.
///
/// Não conhece o [Player] — apenas expõe [superequalizerParams] prontos
/// para serem aplicados via `updateAudioEffects` pelo audio handler.
/// No Riverpod, vira um [Notifier] com estado imutável.
class EqualizerService {
  static const double minGain = 0.0;
  static const double maxGain = 2.0;
  static const double flatGain = 1.0;

  /// As 10 bandas exibidas na UI, mapeadas para bandas espaçadas do
  /// superequalizer (que tem 18 no total) — suficiente para um EQ gráfico
  /// sem sobrecarregar a UI com 18 sliders.
  static const List<EqualizerBand> bands = [
    EqualizerBand(label: '31Hz', key: '1b'),
    EqualizerBand(label: '62Hz', key: '2b'),
    EqualizerBand(label: '125Hz', key: '4b'),
    EqualizerBand(label: '250Hz', key: '5b'),
    EqualizerBand(label: '500Hz', key: '7b'),
    EqualizerBand(label: '1kHz', key: '9b'),
    EqualizerBand(label: '2kHz', key: '11b'),
    EqualizerBand(label: '4kHz', key: '13b'),
    EqualizerBand(label: '8kHz', key: '15b'),
    EqualizerBand(label: '16kHz', key: '17b'),
  ];

  static final Map<EqualizerPreset, List<double>> _presetGains = {
    EqualizerPreset.normal: List.filled(bands.length, flatGain),
    EqualizerPreset.rock: [1.4, 1.3, 1.1, 1.0, 0.9, 1.0, 1.1, 1.2, 1.3, 1.3],
    EqualizerPreset.pop: [
      0.95,
      1.0,
      1.15,
      1.25,
      1.2,
      1.05,
      1.0,
      1.0,
      1.05,
      1.1,
    ],
    EqualizerPreset.jazz: [
      1.2,
      1.15,
      1.05,
      1.1,
      0.95,
      0.95,
      1.0,
      1.1,
      1.15,
      1.2,
    ],
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
    EqualizerPreset.bassBoost: [
      1.6,
      1.5,
      1.3,
      1.1,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
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

  bool _enabled = false;
  EqualizerPreset _activePreset = EqualizerPreset.normal;
  List<double> _bandGains = List.filled(bands.length, flatGain);

  /// Chamado sempre que o estado do equalizador muda, para que o
  /// [Configuration] possa emitir [notifyListeners] e reaplicar no player.
  final void Function() onStateChanged;

  EqualizerService({required this.onStateChanged});

  // ── Getters ───────────────────────────────────────────────────────────────

  bool get enabled => _enabled;
  EqualizerPreset get activePreset => _activePreset;
  List<double> get bandGains => List.unmodifiable(_bandGains);

  /// Monta o mapa de parâmetros no formato esperado pelo
  /// `SuperequalizerSettings.params` do mpv_audio_kit.
  Map<String, double> get superequalizerParams => {
    for (int i = 0; i < bands.length; i++) bands[i].key: _bandGains[i],
  };

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEqEnabledKey) ?? false;

    final presetKey = prefs.getString(_kEqPresetKey);
    _activePreset = EqualizerPreset.values.firstWhere(
      (p) => p.name == presetKey,
      orElse: () => EqualizerPreset.normal,
    );

    _bandGains = List.generate(
      bands.length,
      (i) => prefs.getDouble('$_kEqBandsKeyPrefix$i') ?? flatGain,
    );
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    onStateChanged();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEqEnabledKey, value);
  }

  Future<void> setPreset(EqualizerPreset preset) async {
    if (preset == EqualizerPreset.manual) return;
    _activePreset = preset;
    _bandGains = List.of(
      _presetGains[preset] ?? List.filled(bands.length, flatGain),
    );
    onStateChanged();
    await _persistPresetAndBands();
  }

  /// Ajusta uma banda manualmente. Muda o preset ativo para [EqualizerPreset.manual].
  Future<void> setBandGain(int index, double gain) async {
    if (index < 0 || index >= _bandGains.length) return;
    _bandGains[index] = gain.clamp(minGain, maxGain);
    _activePreset = EqualizerPreset.manual;
    onStateChanged();
    await _persistPresetAndBands();
  }

  Future<void> reset() async {
    _activePreset = EqualizerPreset.normal;
    _bandGains = List.filled(bands.length, flatGain);
    onStateChanged();
    await _persistPresetAndBands();
  }

  Future<void> _persistPresetAndBands() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEqPresetKey, _activePreset.name);
    for (int i = 0; i < _bandGains.length; i++) {
      await prefs.setDouble('$_kEqBandsKeyPrefix$i', _bandGains[i]);
    }
  }
}
