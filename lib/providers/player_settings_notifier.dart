import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_wave_player/providers/music_audio_handler_provider.dart';

part 'player_settings_notifier.g.dart';

const String _kCrossfadeDurationKey = 'crossfade_duration';
const String _kFadeOnPauseResumeKey = 'fade_on_pause_resume';

/// Estado imutável das configurações gerais de reprodução: velocidade,
/// crossfade e fade ao pausar/retomar.
class PlayerSettingsState {
  final double playbackSpeed;
  final int crossfadeDuration;
  final bool fadeOnPauseResume;

  const PlayerSettingsState({
    this.playbackSpeed = 1.0,
    this.crossfadeDuration = 0,
    this.fadeOnPauseResume = false,
  });

  PlayerSettingsState copyWith({
    double? playbackSpeed,
    int? crossfadeDuration,
    bool? fadeOnPauseResume,
  }) {
    return PlayerSettingsState(
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      fadeOnPauseResume: fadeOnPauseResume ?? this.fadeOnPauseResume,
    );
  }
}

/// Configurações gerais de reprodução que sobravam soltas no antigo
/// [Configuration]: velocidade (não persistida — mesmo comportamento
/// original, volta a 1.0x a cada abertura do app), crossfade e fade ao
/// pausar/retomar (ambos persistidos).
@Riverpod(keepAlive: true)
class PlayerSettingsNotifier extends _$PlayerSettingsNotifier {
  @override
  Future<PlayerSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return PlayerSettingsState(
      crossfadeDuration: prefs.getInt(_kCrossfadeDurationKey) ?? 0,
      fadeOnPauseResume: prefs.getBool(_kFadeOnPauseResumeKey) ?? false,
    );
  }

  void setPlaybackSpeed(double speed) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(playbackSpeed: speed));
    ref.read(musicAudioHandlerProvider).setSpeed(speed);
  }

  Future<void> setCrossfadeDuration(int seconds) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(crossfadeDuration: seconds));
    ref.read(musicAudioHandlerProvider).updateCrossfade(seconds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCrossfadeDurationKey, seconds);
  }

  Future<void> setFadeOnPauseResume(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(fadeOnPauseResume: enabled));
    ref.read(musicAudioHandlerProvider).updateFadeOnPauseResume(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFadeOnPauseResumeKey, enabled);
  }
}
