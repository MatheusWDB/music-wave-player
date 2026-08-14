import 'package:flutter/material.dart';

/// Layout do Full Player em orientação paisagem: capa à esquerda,
/// informações/controles roláveis à direita.
class FullPlayerLandscapeLayout extends StatelessWidget {
  final Widget coverWidget;
  final Widget trackInfo;
  final Widget starRating;
  final Widget slider;
  final Widget controls;

  const FullPlayerLandscapeLayout({
    super.key,
    required this.coverWidget,
    required this.trackInfo,
    required this.starRating,
    required this.slider,
    required this.controls,
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
                const SizedBox(height: 8),
                starRating,
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
