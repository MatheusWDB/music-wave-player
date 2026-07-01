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
    final bool isProcessingMetadata =
        config.indexingStatus == IndexingStatus.processingMetadata;
    final bool isCalculatingLoudness =
        config.indexingStatus == IndexingStatus.calculatingLoudness;
    final bool isComplete = config.indexingStatus == IndexingStatus.complete;
    final bool isBusy =
        isScanning || isProcessingMetadata || isCalculatingLoudness;
    final bool isDirectorySet = config.rootDirectory != null;

    String formattedDate = '';
    if (config.lastScanDate != null) {
      formattedDate = DateFormat(
        'dd/MM/yyyy HH:mm',
      ).format(config.lastScanDate!);
    }

    String statusText = "Pronto para começar.";
    double? progressValue = 0.0;

    if (isScanning) {
      final total = config.indexedFileTotal;
      final done = config.indexedFileCount;
      final percent = total > 0
          ? ((done / total) * 100).toStringAsFixed(0)
          : '0';
      statusText = total > 0
          ? "Varrendo e indexando... $done/$total arquivos ($percent%)"
          : "Varrendo e indexando...";
      progressValue = total > 0
          ? done / total
          : null; // indeterminate até saber o total
    } else if (isProcessingMetadata) {
      statusText = config.processingStage ?? "Processando metadados...";
      progressValue = null; // sem total granular nessa fase
    } else if (isCalculatingLoudness) {
      final total = config.loudnessTotal;
      final done = config.loudnessDone;
      final percent = total > 0
          ? ((done / total) * 100).toStringAsFixed(0)
          : '0';
      statusText = "Calculando volume das músicas... $done/$total ($percent%)";
      progressValue = total > 0 ? done / total : null;
    } else if (isComplete) {
      statusText =
          "Varredura concluída! ${config.indexedFileCount} arquivo${config.indexedFileCount == 1 ? '' : 's'} indexado${config.indexedFileCount == 1 ? '' : 's'}.";
      progressValue = 1.0;
    } else if (isDirectorySet) {
      statusText = "Clique em Iniciar Varredura.";
    }

    // CORRIGIDO: botão habilitado sempre que não está varrendo/processando e
    // há diretório definido (inclusive após uma varredura completa, para
    // permitir reindexar)
    final bool canScan = isDirectorySet && !isBusy;

    return Column(
      spacing: 8.0,
      children: [
        LinearProgressIndicator(
          borderRadius: BorderRadius.circular(8.0),
          color: colorScheme.secondary,
          backgroundColor: colorScheme.primary..withValues(alpha: 0.3),
          minHeight: 10.0,
          value: progressValue,
        ),
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurface),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.secondary,
            foregroundColor: colorScheme.onSecondary,
            disabledBackgroundColor: Colors.grey[700],
            disabledForegroundColor: Colors.grey[400],
            minimumSize: const Size.fromHeight(45.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          // CORRIGIDO: usa `canScan` em vez de checar `complete`
          onPressed: canScan
              ? () => context.read<Configuration>().startIndexing()
              : null,
          icon: isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.search),
          label: Text(
            isScanning
                ? "Varrendo..."
                : isProcessingMetadata
                ? "Processando..."
                : isCalculatingLoudness
                ? "Calculando volume..."
                : isComplete
                ? "Reindexar Biblioteca"
                : "Iniciar Varredura",
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          ),
        ),
        if (config.lastScanDate != null)
          Text(
            'Última varredura: $formattedDate',
            style: TextStyle(color: Colors.grey[400], fontSize: 12.0),
          ),
      ],
    );
  }
}
