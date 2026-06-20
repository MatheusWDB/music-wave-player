import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
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
    if (mounted)
      setState(() {
        _tracks = tracks;
        _loading = false;
      });
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
                    final isSelected = _selected.contains(track.id);

                    return InkWell(
                      onTap: () => _toggleSelection(track.id!),
                      onLongPress: () => _toggleSelection(track.id!),
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        color: isSelected
                            ? colorScheme.primaryContainer.withValues(
                                alpha: 0.5,
                              )
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleSelection(track.id!),
                                  activeColor: colorScheme.primary,
                                ),
                              ),
                              CoverArtWidget(
                                coverPath: track.coverPath,
                                size: 48,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Barra de ações do modo seleção
                if (_isSelecting)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _clearSelection,
                            icon: const Icon(Icons.close),
                            tooltip: 'Cancelar seleção',
                          ),
                          Expanded(
                            child: Text(
                              '${_selected.length} selecionada${_selected.length == 1 ? '' : 's'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _unhideSelected,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Reexibir'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
