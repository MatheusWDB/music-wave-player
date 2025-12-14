import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:provider/provider.dart';

class IndexingComponent extends StatelessWidget {
  const IndexingComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Configuration config = context.watch<Configuration>();

    final bool isScanning = config.indexingStatus == IndexingStatus.scanning;
    final bool isComplete = config.indexingStatus == IndexingStatus.complete;
    final bool isDirectorySet = config.rootDirectory != null;

    String formattedDate = '';
    if (config.lastScanDate != null) {
      formattedDate = DateFormat('dd/MM/yyyy').format(config.lastScanDate!);
    }

    String statusText = "Pronto para começar.";
    double? progressValue = 0.0;

    if (isScanning) {
      statusText = "Varrendo e Indexando... (${config.indexedFileCount} arquivos encontrados)";
      progressValue = null;
    } else if (isComplete) {
      statusText = "Varredura concluída! ${config.indexedFileCount} arquivos indexados.";
      progressValue = 1.0;
    } else if (isDirectorySet) {
      statusText = "Clique em Iniciar Varredura.";
    }

    return Column(
      spacing: 8.0,
      children: [
        LinearProgressIndicator(
          borderRadius: BorderRadius.circular(8.0),
          color: colorScheme.secondary,
          backgroundColor: colorScheme.primary,
          minHeight: 10.0,
          value: progressValue,
        ),
        Text(statusText),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.secondary,
            foregroundColor: colorScheme.onSecondary,
            disabledBackgroundColor: Colors.grey[600],
            disabledForegroundColor: colorScheme.onError,
            minimumSize: Size.fromHeight(45.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          onPressed: !isDirectorySet || isScanning
              ? null
              : () => context.read<Configuration>().startIndexing(),
          child: Text(
            "Iniciar Varredura",
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          ),
        ),
        Text(
          config.lastScanDate != null ? 'Última varredura: $formattedDate' : '',
        ),
      ],
    );
  }
}
