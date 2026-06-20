import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/rating_bottom_sheet.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';
import 'package:provider/provider.dart';

class ArtistDetailScreen extends StatefulWidget {
  final String artist;
  final List<MusicTrack> tracks;

  const ArtistDetailScreen({
    super.key,
    required this.artist,
    required this.tracks,
  });

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  late List<MusicTrack> _tracks;

  @override
  void initState() {
    super.initState();
    _tracks = List.of(widget.tracks);
  }

  String _formatDuration(int totalMs) {
    final d = Duration(milliseconds: totalMs);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
    if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _hideTrack(MusicTrack track) async {
    await context.read<Configuration>().hideTracks([track.id!]);
    setState(() => _tracks.removeWhere((t) => t.id == track.id));
    _showSnack('Música ocultada.');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.read<Configuration>();
    final ids = _tracks.map((t) => t.id!).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artist),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'insert_next') {
                config.insertAfterCurrent(ids);
                _showSnack('Músicas adicionadas após a atual');
              } else if (value == 'add_end') {
                config.addToEndOfQueue(ids);
                _showSnack('Músicas adicionadas ao final da fila');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'insert_next',
                child: Row(
                  children: [
                    Icon(Icons.queue_play_next_outlined),
                    SizedBox(width: 12),
                    Text('Tocar a seguir'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'add_end',
                child: Row(
                  children: [
                    Icon(Icons.add_to_queue_outlined),
                    SizedBox(width: 12),
                    Text('Adicionar à fila'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Cabeçalho
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.artist,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tracks.map((t) => t.album).toSet().length} álbum${_tracks.map((t) => t.album).toSet().length == 1 ? '' : 's'} · ${_tracks.length} música${_tracks.length == 1 ? '' : 's'} · ${_formatDuration(_tracks.fold(0, (sum, t) => sum + t.durationMs))}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (_tracks.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      config.playTracks(_tracks);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Tocar'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista de músicas
          Expanded(
            child: _tracks.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma música visível.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
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
                          track.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) async {
                            if (value == 'insert_next') {
                              config.insertAfterCurrent([track.id!]);
                              _showSnack('Música adicionada após a atual');
                            } else if (value == 'add_end') {
                              config.addToEndOfQueue([track.id!]);
                              _showSnack('Música adicionada ao final da fila');
                            } else if (value == 'rate') {
                              await RatingBottomSheet.show(
                                context,
                                track: track,
                              );
                            } else if (value == 'hide') {
                              await _hideTrack(track);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'insert_next',
                              child: Row(
                                children: [
                                  Icon(Icons.queue_play_next_outlined),
                                  SizedBox(width: 12),
                                  Text('Tocar a seguir'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'add_end',
                              child: Row(
                                children: [
                                  Icon(Icons.add_to_queue_outlined),
                                  SizedBox(width: 12),
                                  Text('Adicionar à fila'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'rate',
                              child: Row(
                                children: [
                                  Icon(Icons.star_outline),
                                  SizedBox(width: 12),
                                  Text('Avaliar'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'hide',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_off_outlined),
                                  SizedBox(width: 12),
                                  Text('Ocultar'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          config.playTrack(track.id!);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FullPlayerScreen(initialTrackId: track.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
