import 'package:flutter/material.dart';

/// Bottom sheet arrastável reutilizável: começa em [initialSize] da tela e
/// pode ser expandido até [maxSize] (quase tela cheia) arrastando a alça, o
/// cabeçalho ou a lista interna — sem fechar sozinho abaixo de [minSize].
///
/// [bodyBuilder] recebe o [ScrollController] do sheet e deve repassá-lo para
/// a lista/scroll do conteúdo, para que arrastar a lista (quando já no topo)
/// também redimensione o sheet.
class DraggableSheetScaffold extends StatefulWidget {
  final String title;
  final Widget? header;
  final List<Widget> actions;
  final double initialSize;
  final double minSize;
  final double maxSize;
  final Widget Function(BuildContext context, ScrollController scrollController)
  bodyBuilder;

  const DraggableSheetScaffold({
    super.key,
    required this.title,
    required this.bodyBuilder,
    this.header,
    this.actions = const [],
    this.initialSize = 0.6,
    this.minSize = 0.4,
    this.maxSize = 0.95,
  });

  @override
  State<DraggableSheetScaffold> createState() => _DraggableSheetScaffoldState();
}

class _DraggableSheetScaffoldState extends State<DraggableSheetScaffold> {
  late final DraggableScrollableController _sheetController;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  // Permite redimensionar o sheet arrastando a alça/cabeçalho (área que não
  // é, por si só, um Scrollable ligado ao controller do DraggableScrollableSheet).
  void _onHandleDragUpdate(DragUpdateDetails details, double screenHeight) {
    final deltaFraction = details.delta.dy / screenHeight;
    final newSize = (_sheetController.size - deltaFraction).clamp(
      widget.minSize,
      widget.maxSize,
    );
    _sheetController.jumpTo(newSize);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: widget.initialSize,
      minChildSize: widget.minSize,
      maxChildSize: widget.maxSize,
      expand: false,
      snap: true,
      snapSizes: [widget.minSize, widget.maxSize],
      builder: (context, scrollController) {
        return Material(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) =>
                    _onHandleDragUpdate(details, screenHeight),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child:
                                widget.header ??
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                          ),
                          ...widget.actions,
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            tooltip: 'Fechar',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: widget.bodyBuilder(context, scrollController)),
            ],
          ),
        );
      },
    );
  }
}
