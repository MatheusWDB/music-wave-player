import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:music_wave_player/components/indexing_component.dart';
import 'package:music_wave_player/components/path_component.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

/// Card com os dois passos de configuração da biblioteca: seleção do
/// diretório raiz (com pedido de permissão) e indexação.
class DirectoryPickerCard extends StatelessWidget {
  const DirectoryPickerCard({super.key});

  Future<void> _pickRootDirectory(BuildContext context) async {
    PermissionStatus status = await Permission.audio.request();

    if (!status.isGranted) {
      if (context.mounted) {
        if (status.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Permissão de Armazenamento permanentemente negada. Abra as Configurações do App.",
              ),
              action: SnackBarAction(
                label: "Configurações",
                onPressed: openAppSettings,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Permissão de Armazenamento negada. Necessária para a indexação.",
              ),
            ),
          );
        }
      }
      return;
    }

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null && context.mounted) {
      context.read<Configuration>().rootDirectory = selectedDirectory;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          spacing: 16.0,
          children: [
            Text(
              "Passo 1: Selecione o Diretório Raiz",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16.0,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              "O app buscará arquivos de áudio apenas neste caminho e subpastas.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[300]),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary),
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.all(10.0),
              width: double.infinity,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_DirectoryLabel(), PathComponent()],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                minimumSize: const Size.fromHeight(45.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: () async => _pickRootDirectory(context),
              child: const Text(
                "Escolher Pasta de Música",
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Text(
              "Passo 2: Indexação da Biblioteca",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16.0,
                fontWeight: FontWeight.w400,
              ),
            ),
            const IndexingComponent(),
          ],
        ),
      ),
    );
  }
}

class _DirectoryLabel extends StatelessWidget {
  const _DirectoryLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      "Diretório Selecionado",
      style: TextStyle(color: Colors.grey[400], fontSize: 12.0),
    );
  }
}
