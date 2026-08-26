import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/providers/playback_notifier.dart';

part 'current_track_provider.g.dart';

/// Faixa atualmente carregada, derivada do cruzamento entre
/// [PlaybackNotifier] (id da última faixa tocada) e [IndexingNotifier]
/// (lista de faixas indexadas). Substitui o getter `Configuration.currentTrack`.
@riverpod
MusicTrack? currentTrack(Ref ref) {
  final playbackState = ref.watch(playbackNotifierProvider).valueOrNull;
  final id = playbackState?.lastPlayedMusicId;
  if (id == null) return null;

  final indexingState = ref.watch(indexingNotifierProvider).valueOrNull;
  final tracks = indexingState?.indexedTracks ?? const [];
  return tracks.where((t) => t.id == id).firstOrNull;
}

/// Lista de faixas reproduzidas recentemente, na ordem do histórico.
/// Substitui o getter `Configuration.recentlyPlayedTracks`.
@riverpod
List<MusicTrack> recentlyPlayedTracks(Ref ref) {
  final playbackState = ref.watch(playbackNotifierProvider).valueOrNull;
  final ids = playbackState?.recentlyPlayedIds ?? const [];

  final indexingState = ref.watch(indexingNotifierProvider).valueOrNull;
  final tracks = indexingState?.indexedTracks ?? const [];

  return ids
      .map((id) => tracks.where((t) => t.id == id).firstOrNull)
      .whereType<MusicTrack>()
      .toList();
}
