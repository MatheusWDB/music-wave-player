import 'package:flutter/material.dart';
import 'package:music_wave_player/models/music_track.dart';

class MusicsTab extends StatelessWidget {
  final List<MusicTrack> tracks;

  const MusicsTab({super.key, required this.tracks});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 10.0),
      itemCount: tracks.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 12.0),
      itemBuilder: (context, index) => InkWell(
        onTap: () {},
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tracks[index].title),
                    Text(tracks[index].artist),
                    Text(tracks[index].album),
                  ],
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.queue_music_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
