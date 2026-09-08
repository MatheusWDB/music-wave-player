import 'package:flutter/material.dart';
import 'package:music_wave_player/components/directory_picker_card.dart';
import 'package:music_wave_player/components/library_setup_header.dart';

class RootDirectoryConfigScreen extends StatelessWidget {
  const RootDirectoryConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca')),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10.0,
          children: [
            const LibrarySetupHeader(),
            const DirectoryPickerCard(),
            Text(
              "Arquivos de áudio válidos: .mp3, .m4a, etc.",
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
