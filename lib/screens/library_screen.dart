import 'package:flutter/material.dart';
import 'package:music_wave_player/components/library_components/mini_player_component.dart';
import 'package:music_wave_player/components/library_components/tabs_component.dart';
import 'package:music_wave_player/screens/root_directory_config_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Row(
                children: [
                  Text('LocalPlay Biblioteca'),
                  Row(
                    children: [
                      IconButton(onPressed: () {}, icon: Icon(Icons.search)),
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RootDirectoryConfigScreen(),
                          ),
                        ),
                        icon: Icon(Icons.settings),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: TabsComponent()),
            MiniPlayerComponent(),
          ],
        ),
      ),
    );
  }
}
