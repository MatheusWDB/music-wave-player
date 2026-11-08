import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/round_play_button.dart';
import 'package:music_wave_player/components/shuffle_toggle_button.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/current_track_provider.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/providers/playback_notifier.dart';

/// Botão de play de uma lista de faixas. Se a faixa atual pertence à lista,
/// funciona como play/pausa (sem reiniciar a fila); caso contrário, chama
/// [onStart] para iniciar a lista. Com [showShuffle], exibe também o botão de
/// aleatório à esquerda.
class ListPlayButton extends ConsumerWidget {
  final List<MusicTrack> tracks;
  final VoidCallback onStart;
  final bool showShuffle;

  const ListPlayButton({
    super.key,
    required this.tracks,
    required this.onStart,
    this.showShuffle = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(currentTrackProvider);
    final isPlaying = ref.watch(
      playbackNotifierProvider.select((s) => s.valueOrNull?.isPlaying ?? false),
    );
    final currentInList =
        currentTrack != null && tracks.any((t) => t.id == currentTrack.id);

    final playButton = RoundPlayButton(
      isPlaying: currentInList && isPlaying,
      onPressed: () {
        if (!currentInList) {
          onStart();
          return;
        }
        final indexedTracks =
            ref.read(indexingNotifierProvider).valueOrNull?.indexedTracks ??
            const <MusicTrack>[];
        ref
            .read(playbackNotifierProvider.notifier)
            .togglePlayPause(
              indexedTracks: indexedTracks,
              currentTrackPath: currentTrack.path,
            );
      },
    );

    if (!showShuffle) return playButton;

    final isShuffleActive = ref.watch(
      playbackNotifierProvider.select(
        (s) => s.valueOrNull?.isShuffleActive ?? false,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShuffleToggleButton(
          isActive: isShuffleActive,
          onPressed: () =>
              ref.read(playbackNotifierProvider.notifier).toggleShuffle(),
        ),
        const SizedBox(width: 8.0),
        playButton,
      ],
    );
  }
}
