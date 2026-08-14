import 'package:flutter/material.dart';
import 'package:music_wave_player/components/directory_picker_card.dart';
import 'package:music_wave_player/components/library_setup_header.dart';

class RootDirectoryConfigScreen extends StatelessWidget {
  const RootDirectoryConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca')),
      body: const SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10.0,
          children: [
            LibrarySetupHeader(),
            DirectoryPickerCard(),
            Text(
              "Arquivos de áudio válidos: .mp3, .m4a, etc.",
              style: TextStyle(color: Colors.grey, fontSize: 12.0),
            ),
          ],
        ),
      ),
    );
  }
}
