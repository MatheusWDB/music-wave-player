import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/services/music_audio_handler.dart';

/// Provider do [MusicAudioHandler].
///
/// Como o handler agora depende só de [Ref] (não mais de um objeto
/// `Configuration` construído manualmente), o próprio Riverpod resolve a
/// criação — sem necessidade de override manual em `main.dart`.
final musicAudioHandlerProvider = Provider<MusicAudioHandler>((ref) {
  final handler = MusicAudioHandler(ref);
  ref.onDispose(handler.dispose);
  return handler;
});
