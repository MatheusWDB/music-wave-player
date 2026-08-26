import 'package:music_wave_player/providers/indexing_notifier.dart';

/// Resultado computado do estado de indexação, pronto para exibição.
///
/// Centraliza a lógica de decisão de texto/progresso/habilitação do botão
/// que antes vivia dentro do `build()` do [IndexingComponent] — sem
/// nenhuma dependência de widgets, facilita tanto testes quanto o consumo
/// direto do [IndexingState] do [IndexingNotifier].
class IndexingStatusInfo {
  final String statusText;
  final double? progressValue;
  final bool isBusy;
  final bool canScan;
  final String buttonLabel;

  const IndexingStatusInfo({
    required this.statusText,
    required this.progressValue,
    required this.isBusy,
    required this.canScan,
    required this.buttonLabel,
  });

  factory IndexingStatusInfo.from(IndexingState state) {
    final isScanning = state.indexingStatus == IndexingStatus.scanning;
    final isProcessingMetadata =
        state.indexingStatus == IndexingStatus.processingMetadata;
    final isCalculatingLoudness =
        state.indexingStatus == IndexingStatus.calculatingLoudness;
    final isComplete = state.indexingStatus == IndexingStatus.complete;
    final isBusy = state.isBusy;
    final isDirectorySet = state.rootDirectory != null;

    String statusText = 'Pronto para começar.';
    double? progressValue = 0.0;

    if (isScanning) {
      final total = state.indexedFileTotal;
      final done = state.indexedFileCount;
      final percent = total > 0
          ? ((done / total) * 100).toStringAsFixed(0)
          : '0';
      statusText = total > 0
          ? 'Varrendo e indexando... $done/$total arquivos ($percent%)'
          : 'Varrendo e indexando...';
      progressValue = total > 0 ? done / total : null;
    } else if (isProcessingMetadata) {
      statusText = state.processingStage ?? 'Processando metadados...';
      progressValue = null;
    } else if (isCalculatingLoudness) {
      final total = state.loudnessTotal;
      final done = state.loudnessDone;
      final percent = total > 0
          ? ((done / total) * 100).toStringAsFixed(0)
          : '0';
      statusText = 'Calculando volume das músicas... $done/$total ($percent%)';
      progressValue = total > 0 ? done / total : null;
    } else if (isComplete) {
      statusText =
          'Varredura concluída! ${state.indexedFileCount} arquivo'
          '${state.indexedFileCount == 1 ? '' : 's'} indexado'
          '${state.indexedFileCount == 1 ? '' : 's'}.';
      progressValue = 1.0;
    } else if (isDirectorySet) {
      statusText = 'Clique em Iniciar Varredura.';
    }

    final buttonLabel = isScanning
        ? 'Varrendo...'
        : isProcessingMetadata
        ? 'Processando...'
        : isCalculatingLoudness
        ? 'Calculando volume...'
        : isComplete
        ? 'Reindexar Biblioteca'
        : 'Iniciar Varredura';

    return IndexingStatusInfo(
      statusText: statusText,
      progressValue: progressValue,
      isBusy: isBusy,
      canScan: isDirectorySet && !isBusy,
      buttonLabel: buttonLabel,
    );
  }
}
