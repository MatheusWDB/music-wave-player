import 'package:flutter/material.dart';
import 'package:music_wave_player/components/hidden_track_tile.dart';
import 'package:music_wave_player/components/unhide_action_bar.dart';
import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:provider/provider.dart';

class HiddenTracksScreen extends StatefulWidget {
  const HiddenTracksScreen({super.key});

  @override
  State<HiddenTracksScreen> createState() => _HiddenTracksScreenState();
}

class _HiddenTracksScreenState extends State<HiddenTracksScreen> {
  List<MusicTrack> _tracks = [];
  final Set<int> _selected = {};
  bool _loading = true;

  bool get _isSelecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tracks = await MusicDatabase.instance.readHiddenTracks();
    if (mounted) {
      setState(() {
        _tracks = tracks;
        _loading = false;
      });
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _clearSelection() => setState(() => _selected.clear());

  Future<void> _unhideSelected() async {
    final ids = _selected.toList();
    _clearSelection();
    await context.read<Configuration>().unhideTracks(ids);
    await _load();
  }

  Future<void> _unhideAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reexibir todas'),
        content: const Text('Deseja reexibir todas as músicas ocultas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reexibir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await context.read<Configuration>().unhideAllTracks();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Músicas ocultas'),
        actions: [
          if (_tracks.isNotEmpty && !_isSelecting)
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              tooltip: 'Reexibir todas',
              onPressed: _unhideAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tracks.isEmpty
          ? Center(
              child: Text(
                'Nenhuma música oculta.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          : Stack(
              children: [
                ListView.separated(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: _isSelecting ? 80 : 8,
                  ),
                  itemCount: _tracks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final track = _tracks[index];
                    return HiddenTrackTile(
                      track: track,
                      isSelected: _selected.contains(track.id),
                      onToggleSelection: () => _toggleSelection(track.id!),
                    );
                  },
                ),
                if (_isSelecting)
                  UnhideActionBar(
                    selectedCount: _selected.length,
                    onClear: _clearSelection,
                    onUnhide: _unhideSelected,
                  ),
              ],
            ),
    );
  }
}
