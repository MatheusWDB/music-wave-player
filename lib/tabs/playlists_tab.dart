import 'package:flutter/material.dart';

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(45.0)),
          onPressed: () {},
          child: Text("Criar Nova Playlist"),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: 3,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 12.0),
            itemBuilder: (context, index) => InkWell(
              onTap: () {},
              child: Card(
                child: Row(
                  children: [
                    Column(children: [Text("Nome"), Text("N Músicas")]),
                    Icon(Icons.chevron_right_outlined),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
