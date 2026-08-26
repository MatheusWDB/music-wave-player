import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/star_rating_widget.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/current_track_provider.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';

/// Linha de avaliação por estrelas da faixa atual no Full Player.
/// Observa o rating via [currentTrackProvider] para refletir mudanças em
/// tempo real (ex: avaliação feita pelo bottom sheet de avaliação).
class FullPlayerStarRating extends ConsumerWidget {
  final MusicTrack track;

  const FullPlayerStarRating({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(currentTrackProvider)?.rating ?? 0;

    return StarRatingWidget(
      rating: rating,
      starSize: 30,
      onRatingChanged: (v) =>
          ref.read(indexingNotifierProvider.notifier).setRating(track.id!, v),
    );
  }
}
