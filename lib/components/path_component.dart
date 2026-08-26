import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';

class PathComponent extends ConsumerWidget {
  const PathComponent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootDirectory = ref.watch(
      indexingNotifierProvider.select((s) => s.valueOrNull?.rootDirectory),
    );

    return Text(
      rootDirectory == null ? "Nenhum diretório selecionado." : rootDirectory,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: rootDirectory == null ? Colors.grey[600] : null,
        fontStyle: rootDirectory == null ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}
