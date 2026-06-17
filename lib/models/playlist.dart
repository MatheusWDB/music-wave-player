class Playlist {
  final int? id;
  final String name;

  /// Faixas da playlist em ordem. Pode estar vazio se carregado sem faixas.
  final List<int> trackIds;

  Playlist({this.id, required this.name, this.trackIds = const []});

  Playlist copyWith({int? id, String? name, List<int>? trackIds}) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
    );
  }

  @override
  String toString() =>
      'Playlist(id: $id, name: $name, tracks: ${trackIds.length})';
}
