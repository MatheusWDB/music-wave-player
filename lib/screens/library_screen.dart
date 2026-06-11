import 'package:flutter/material.dart';
import 'package:music_wave_player/components/library_components/mini_player_component.dart';
import 'package:music_wave_player/components/library_components/tabs_component.dart';
import 'package:music_wave_player/screens/root_directory_config_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  // CORRIGIDO: título ocupa o espaço disponível
                  Expanded(
                    child: Text(
                      'LocalPlay',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.search, color: colorScheme.onSurface),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RootDirectoryConfigScreen(),
                      ),
                    ),
                    icon: Icon(Icons.settings, color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            const Expanded(child: TabsComponent()),
            const Padding(
              padding: EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 8.0),
              child: MiniPlayerComponent(),
            ),
          ],
        ),
      ),
    );
  }
}
