import 'dart:io';

/// Padrão de nome de arquivo da biblioteca: "Primeiro Artista - Título.ext".
class TrackFileNamer {
  TrackFileNamer._();

  /// Valor que o parser grava quando o arquivo não tem tag de artista.
  static const unknownArtist = 'Artista Desconhecido';

  static const _maxBaseLength = 120;

  /// Proibidos em nome de arquivo e simplesmente removidos. "/" e "\" viram
  /// caracteres parecidos (como o yt-dlp faz com "⧸"), para "AC/DC" não
  /// virar "ACDC".
  static final _forbidden = RegExp(r'[:*?"<>|]');

  /// Ao comparar nomes, ignora esses caracteres e os parecidos com eles
  /// (barras e símbolos de largura total que outros programas usam no lugar),
  /// além do "&", que costuma ser escrito no lugar de "/" ("A & B" x "A / B").
  static final _ignoredWhenComparing = RegExp(
    r'[&\\/:*?"<>|\u29F8\u29F9\u2215\u2044\uFF0F\uFF3C\uFF1A\uFF0A\uFF1F\uFF02\uFF1C\uFF1E\uFF5C]',
  );

  /// Subpasta de [path] relativa a [rootDirectory] (vazio se o arquivo está
  /// na raiz); null se o arquivo não está dentro da raiz.
  static String? relativeDir(String path, String rootDirectory) {
    final root = rootDirectory.endsWith('/')
        ? rootDirectory.substring(0, rootDirectory.length - 1)
        : rootDirectory;
    if (!path.startsWith('$root/')) return null;
    final relative = path.substring(root.length + 1);
    final slash = relative.lastIndexOf('/');
    return slash == -1 ? '' : relative.substring(0, slash);
  }

  /// Primeiro artista da tag. O único separador de artistas é o ";" (como
  /// no resto do app); "/", "&" e "," fazem parte do nome.
  static String firstArtist(String artist) => artist.split(';').first.trim();

  static String _sanitize(String text) {
    return text
        .replaceAll('/', '\u29F8')
        .replaceAll('\\', '\u29F9')
        .replaceAll(_forbidden, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _comparable(String name) {
    return name
        .toLowerCase()
        .replaceAll('\u2019', "'")
        .replaceAll(_ignoredWhenComparing, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Nome-base (sem extensão), ou null se não dá para montar o padrão — sem
  /// artista (vazio ou "Artista Desconhecido") o arquivo não é renomeado.
  static String? baseName({required String artist, required String title}) {
    final first = firstArtist(artist);
    if (first.isEmpty || first == unknownArtist) return null;

    var base = _sanitize('$first - $title');
    if (base.length > _maxBaseLength) {
      base = base.substring(0, _maxBaseLength).trim();
    }
    return base.isEmpty ? null : base;
  }

  /// Nome final do arquivo em [dir], mantendo a extensão de [currentName].
  /// Retorna null quando não há o que renomear: o arquivo já está no padrão
  /// ou não dá para montar um nome. Se o nome já existir na pasta, acrescenta
  /// " (2)", " (3)"...
  static String? targetFileName({
    required String dir,
    required String currentName,
    required String artist,
    required String title,
  }) {
    final base = baseName(artist: artist, title: title);
    if (base == null) return null;

    final dot = currentName.lastIndexOf('.');
    final extension = dot == -1 ? '' : currentName.substring(dot);
    final currentComparable = _comparable(currentName);

    var name = '$base$extension';
    var counter = 2;
    while (true) {
      // Nome equivalente ao atual (caixa, barras e símbolos parecidos
      // ignorados) significa que nada muda.
      if (_comparable(name) == currentComparable) return null;
      if (!File('$dir/$name').existsSync()) return name;
      name = '$base ($counter)$extension';
      counter++;
    }
  }
}
