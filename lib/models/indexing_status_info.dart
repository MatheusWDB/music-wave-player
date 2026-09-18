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
  final int stageIndex;
  final int stageTotal;

  const IndexingStatusInfo({
    required this.statusText,
    required this.progressValue,
    required this.isBusy,
    required this.canScan,
    required this.buttonLabel,
    required this.stageIndex,
    required this.stageTotal,
  });

  factory IndexingStatusInfo.from(IndexingState state) {
    const totalStages = 3; // Varredura, Processamento, Loudness

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
    int stageIndex = 0;

    if (isScanning) {
      stageIndex = 1;
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
      stageIndex = 2;
      final total = state.metadataStageTotal;
      final done = state.metadataStageDone;
      final label = state.processingStage ?? 'Processando metadados...';
      final percent = total > 0
          ? ((done / total) * 100).toStringAsFixed(0)
          : '0';
      statusText = total > 0 ? '$label $done/$total ($percent%)' : label;
      progressValue = total > 0 ? done / total : null;
    } else if (isCalculatingLoudness) {
      stageIndex = 3;
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
      stageIndex: stageIndex,
      stageTotal: totalStages,
    );
  }
}
