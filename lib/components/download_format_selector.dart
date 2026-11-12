import 'package:flutter/material.dart';
import 'package:music_wave_player/services/download_service.dart';

/// Seletor do formato de saída (M4A / MP3). O MP3 só fica habilitado se o
/// build do ffmpeg tiver o encoder correspondente.
class DownloadFormatSelector extends StatelessWidget {
  final DownloadFormat value;
  final bool mp3Available;
  final ValueChanged<DownloadFormat> onChanged;

  const DownloadFormatSelector({
    super.key,
    required this.value,
    required this.mp3Available,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Formato do arquivo',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 8),
        SegmentedButton<DownloadFormat>(
          segments: [
            for (final format in DownloadFormat.values)
              ButtonSegment(
                value: format,
                label: Text(format.label),
                enabled: format != DownloadFormat.mp3 || mp3Available,
              ),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        if (!mp3Available)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'MP3 indisponível neste build do ffmpeg.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}
