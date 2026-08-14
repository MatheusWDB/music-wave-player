import 'package:flutter/material.dart';
import 'package:music_wave_player/components/star_rating_widget.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:provider/provider.dart';

/// Linha de avaliação por estrelas da faixa atual no Full Player.
/// Observa o rating via [Configuration] para refletir mudanças em tempo
/// real (ex: avaliação feita pelo bottom sheet de avaliação).
class FullPlayerStarRating extends StatelessWidget {
  final MusicTrack track;

  const FullPlayerStarRating({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final rating = context.select<Configuration, double>(
      (c) => c.currentTrack?.rating ?? 0,
    );

    return StarRatingWidget(
      rating: rating,
      starSize: 30,
      onRatingChanged: (v) =>
          context.read<Configuration>().setRating(track.id!, v),
    );
  }
}
