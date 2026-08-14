import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/models/music_track.dart';

/// Item de lista com checkbox para seleção múltipla de músicas.
class SelectableTrackTile extends StatelessWidget {
  final MusicTrack track;
  final bool isSelected;
  final VoidCallback onToggle;

  const SelectableTrackTile({
    super.key,
    required this.track,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CoverArtWidget(
        coverPath: track.coverPath,
        size: 44,
        borderRadius: BorderRadius.circular(6),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (_) => onToggle(),
        activeColor: colorScheme.primary,
      ),
      onTap: onToggle,
    );
  }
}
