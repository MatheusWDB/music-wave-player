import 'package:flutter/material.dart';

/// Layout do Full Player em orientação retrato: capa grande no topo,
/// seguida de informações da faixa, avaliação, slider e controles.
class FullPlayerPortraitLayout extends StatelessWidget {
  final Widget coverWidget;
  final Widget trackInfo;
  final Widget starRating;
  final Widget slider;
  final Widget controls;

  const FullPlayerPortraitLayout({
    super.key,
    required this.coverWidget,
    required this.trackInfo,
    required this.starRating,
    required this.slider,
    required this.controls,
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
          const SizedBox(height: 12),
          starRating,
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
