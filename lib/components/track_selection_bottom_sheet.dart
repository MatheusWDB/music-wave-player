import 'package:flutter/material.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';

class TrackSelectionBottomSheet extends StatefulWidget {
  final List<MusicTrack> tracks;
  final List<int> alreadySelected;
  final String title;

  const TrackSelectionBottomSheet._({
    required this.tracks,
    required this.alreadySelected,
    required this.title,
  });

  static Future<List<int>?> show(
    BuildContext context, {
    required List<MusicTrack> tracks,
    List<int> alreadySelected = const [],
    String title = 'Selecionar músicas',
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrackSelectionBottomSheet._(
        tracks: tracks,
        alreadySelected: alreadySelected,
        title: title,
      ),
    );
  }

  @override
  State<TrackSelectionBottomSheet> createState() =>
      _TrackSelectionBottomSheetState();
}

class _TrackSelectionBottomSheetState extends State<TrackSelectionBottomSheet> {
  late final Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.alreadySelected);
  }

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Alça
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${_selected.length} selecionada${_selected.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 13, color: colorScheme.primary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Lista
            Expanded(
              child: ListView.builder(
                itemCount: widget.tracks.length,
                itemBuilder: (context, index) {
                  final track = widget.tracks[index];
                  final isSelected = _selected.contains(track.id);
                  return ListTile(
                    leading: CoverArtWidget(
                      coverPath: track.coverPath,
                      size: 44,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggle(track.id!),
                      activeColor: colorScheme.primary,
                    ),
                    onTap: () => _toggle(track.id!),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Botões
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(context, _selected.toList()),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Confirmar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
