import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/indexing_status_info.dart';
import 'package:provider/provider.dart';

class IndexingComponent extends StatelessWidget {
  const IndexingComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Configuration config = context.watch<Configuration>();
    final info = IndexingStatusInfo.from(config);

    String? formattedDate;
    if (config.lastScanDate != null) {
      formattedDate = DateFormat(
        'dd/MM/yyyy HH:mm',
      ).format(config.lastScanDate!);
    }

    return Column(
      spacing: 8.0,
      children: [
        LinearProgressIndicator(
          borderRadius: BorderRadius.circular(8.0),
          color: colorScheme.secondary,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.3),
          minHeight: 10.0,
          value: info.progressValue,
        ),
        Text(
          info.statusText,
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
          onPressed: info.canScan
              ? () => context.read<Configuration>().startIndexing()
              : null,
          icon: info.isBusy
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
            info.buttonLabel,
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          ),
        ),
        if (formattedDate != null)
          Text(
            'Última varredura: $formattedDate',
            style: TextStyle(color: Colors.grey[400], fontSize: 12.0),
          ),
      ],
    );
  }
}
