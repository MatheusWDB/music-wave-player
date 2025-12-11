import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:provider/provider.dart';

class PathComponent extends StatelessWidget {
  const PathComponent({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      context.watch<Configuration>().rootDirectory == null
          ? "Nenhum diretório selecionado."
          : context.watch<Configuration>().rootDirectory!,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: context.watch<Configuration>().rootDirectory == null
            ? Colors.grey[600]
            : null,
        fontStyle: context.watch<Configuration>().rootDirectory == null
            ? FontStyle.italic
            : FontStyle.normal,
      ),
    );
  }
}
