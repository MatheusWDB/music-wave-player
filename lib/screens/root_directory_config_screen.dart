import 'package:flutter/material.dart';
import 'package:music_wave_player/components/root_directory_config_components/indexing_component.dart';
import 'package:music_wave_player/components/root_directory_config_components/path_component.dart';

class RootDirectoryConfigScreen extends StatelessWidget {
  const RootDirectoryConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(18.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10.0,
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 6.0,
                  children: [
                    Icon(Icons.headphones),
                    Text(
                      "LocalPlay",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 28.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  "Configure sua Biblioteca de Música",
                  style: TextStyle(color: colorScheme.primary, fontSize: 16.0),
                ),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  spacing: 16.0,
                  children: [
                    Text(
                      "Passo 1: Selecione o Diretório Raiz",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      "O app buscará arquivos de áudio apenas neste caminho e subpastas.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.primary),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: EdgeInsets.all(10.0),
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Diretório Selecionado",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12.0,
                            ),
                          ),
                          PathComponent(),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                        minimumSize: Size.fromHeight(45.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {},
                      child: Text(
                        "Escolher Pasta de Música",
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Divider(),
                    Text(
                      "Passo 2: Indexação da Biblioteca",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    IndexingComponent(),
                  ],
                ),
              ),
            ),
            Text(
              "Arquivos de áudio válidos: .mp3, .m4a, etc.",
              style: TextStyle(color: Colors.grey, fontSize: 12.0),
            ),
          ],
        ),
      ),
    );
  }
}
