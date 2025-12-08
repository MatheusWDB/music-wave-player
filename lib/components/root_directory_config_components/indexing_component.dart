import 'package:flutter/material.dart';

class IndexingComponent extends StatefulWidget {
  const IndexingComponent({super.key});

  @override
  State<IndexingComponent> createState() => _IndexingComponentState();
}

class _IndexingComponentState extends State<IndexingComponent> {
  String? path;

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      spacing: 8.0,
      children: [
        LinearProgressIndicator(
          borderRadius: BorderRadius.circular(8.0),
          minHeight: 10.0,
          value: 0.5,
        ),
        Text("Pronto para começar."),
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
          onPressed: path == null ? null : () {},
          child: Text(
            "Iniciar Varredura",
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
