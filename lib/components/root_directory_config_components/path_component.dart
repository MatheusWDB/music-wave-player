import 'package:flutter/material.dart';

class PathComponent extends StatefulWidget {
  const PathComponent({super.key});

  @override
  State<PathComponent> createState() => _PathComponentState();
}

class _PathComponentState extends State<PathComponent> {
  String? path;

  @override
  Widget build(BuildContext context) {
    return Text(
      path == null ? "Nenhum diretório selecionado." : path!,
      maxLines: 2,
      style: TextStyle(
        color: path == null ? Colors.grey[600] : null,
        fontStyle: path == null ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}
