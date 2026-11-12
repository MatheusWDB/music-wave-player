import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/services/ffmpeg_service.dart';
import 'package:music_wave_player/services/saf_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yt_extractor/yt_extractor.dart' as yte;
import 'package:ytdlp_flutter/ytdlp_flutter.dart';

/// Erro de download/salvamento com mensagem pronta para exibir ao usuário.
class DownloadException implements Exception {
  final String message;
  const DownloadException(this.message);

  @override
  String toString() => message;
}

/// Cancelamento pedido pelo usuário (não é um erro a exibir).
class DownloadCancelledException extends DownloadException {
  const DownloadCancelledException() : super('Download cancelado.');
}

/// Formatos de saída suportados. Só os que o leitor de tags do app entende
/// (m4a e mp3); outros formatos apareceriam como "Artista Desconhecido".
enum DownloadFormat {
  m4a('M4A', 'm4a'),
  mp3('MP3', 'mp3');

  final String label;
  final String extension;
  const DownloadFormat(this.label, this.extension);
}

/// Dados básicos do vídeo, exibidos antes de baixar.
class DownloadVideoInfo {
  final String id;
  final String title;
  final String channel;
  final Duration? duration;

  /// URLs de capa em ordem de preferência (maior resolução primeiro).
  final List<String> thumbnailUrls;

  const DownloadVideoInfo({
    required this.id,
    required this.title,
    required this.channel,
    required this.duration,
    required this.thumbnailUrls,
  });
}

/// Playlist listada para seleção antes de baixar.
class DownloadPlaylist {
  final String title;
  final String author;
  final List<DownloadVideoInfo> items;

  /// true se a playlist tinha mais vídeos que o limite listado.
  final bool truncated;

  const DownloadPlaylist({
    required this.title,
    required this.author,
    required this.items,
    required this.truncated,
  });
}

/// Tags que serão gravadas no arquivo. Vários artistas separados por ";".
class DownloadTags {
  final String title;
  final String artist;
  final String album;

  const DownloadTags({
    required this.title,
    required this.artist,
    required this.album,
  });
}

/// Áudio já baixado para o cache, ainda fora da biblioteca.
class DownloadedMedia {
  final String audioPath;
  final String? thumbnailPath;

  /// AAC dentro de mp4 pode ser copiado sem recodificar; outros formatos
  /// (ex: webm/opus) são convertidos para AAC na hora de salvar.
  final bool isAacMp4;

  const DownloadedMedia({
    required this.audioPath,
    required this.thumbnailPath,
    required this.isAacMp4,
  });
}

/// Baixa áudio do YouTube com o yt-dlp rodando no próprio aparelho
/// (ytdlp_flutter) e grava o resultado na pasta raiz da biblioteca, com as
/// tags já definidas.
class DownloadService {
  DownloadService._();

  // O yt_extractor (NewPipe) só lista playlists; o download é do yt-dlp.
  static final yte.YtExtractor _extractor = yte.YtExtractor();

  static const int _maxPlaylistItems = 200;

  static final RegExp _playlistIdPattern = RegExp(r'[?&]list=([A-Za-z0-9_-]+)');

  static void _log(String msg) => debugPrint('[Download] $msg');

  // Títulos de vídeo costumam trazer "(Official Video)", "[Lyrics]" etc.
  // Só remove grupos entre () ou [] que contenham essas palavras — "(Ao Vivo)"
  // e "(feat. X)" são preservados.
  static final RegExp _noiseGroup = RegExp(
    r'\s*[\(\[][^\)\]]*(official|oficial|video|vídeo|audio|áudio|lyric|letra|clipe|visualizer|\bhd\b|4k)[^\)\]]*[\)\]]',
    caseSensitive: false,
  );

  static final RegExp _videoIdPattern = RegExp(
    r'(?:youtu\.be/|[?&]v=|/shorts/|/embed/|/live/)([A-Za-z0-9_-]{11})',
  );

  /// Inicia o motor do yt-dlp em segundo plano (extração e checagem de
  /// atualização) para que a primeira música não pague esse custo.
  static Future<void> warmUp() async {
    try {
      await Ytdlp.init();
    } catch (e) {
      _log('warmUp erro: $e');
    }
  }

  // ── Metadados do vídeo ────────────────────────────────────────────────────

  /// Extrai o ID do vídeo; ignora parâmetros como ?si= e &list=.
  static String? _extractVideoId(String url) =>
      _videoIdPattern.firstMatch(url)?.group(1);

  /// URL limpa, sem playlist: o yt-dlp baixaria a lista inteira se o link
  /// original trouxesse &list=.
  static String _canonicalUrl(String id) =>
      'https://www.youtube.com/watch?v=$id';

  static Future<DownloadVideoInfo> fetchInfo(String url) async {
    final id = _extractVideoId(url);
    if (id == null) {
      // Link de playlist não traz ID de vídeo; avisa em vez de "inválido".
      if (url.contains('list=') || url.contains('/playlist')) {
        throw const DownloadException(
          'Esse é um link de playlist. Cole o link de um vídeo.',
        );
      }
      throw const DownloadException('Link do YouTube inválido.');
    }

    try {
      await Ytdlp.init();
      final info = await Ytdlp.getVideoInfo(_canonicalUrl(id));
      final seconds = (info.durationSeconds as num?)?.toInt();
      return DownloadVideoInfo(
        id: id,
        title: '${info.title}',
        channel: info.uploader ?? '',
        duration: (seconds != null && seconds > 0)
            ? Duration(seconds: seconds)
            : null,
        thumbnailUrls: _thumbnailUrls(id),
      );
    } catch (e, st) {
      _log('fetchInfo erro: $e\n$st');
      throw const DownloadException(
        'Não foi possível obter o vídeo. Confira o link e a conexão.',
      );
    }
  }

  static List<String> _thumbnailUrls(String id) => [
    'https://i.ytimg.com/vi/$id/maxresdefault.jpg',
    'https://i.ytimg.com/vi/$id/hqdefault.jpg',
  ];

  /// Link de playlist pura (sem ID de vídeo). Links de vídeo com &list=
  /// continuam sendo tratados como um vídeo só.
  static bool isPlaylistUrl(String url) =>
      _extractVideoId(url) == null &&
      (url.contains('list=') || url.contains('/playlist'));

  /// Lista os vídeos de uma playlist pública ou não listada.
  static Future<DownloadPlaylist> fetchPlaylist(String url) async {
    final id = _playlistIdPattern.firstMatch(url)?.group(1);
    if (id == null) {
      throw const DownloadException('Link de playlist inválido.');
    }

    try {
      await _extractor.init();
      final playlist = await _extractor.getPlaylist(
        'https://www.youtube.com/playlist?list=$id',
      );
      _log('fetchPlaylist: id=$id, nome="${playlist.name}"');

      var batch = playlist.items;
      var hasNext = playlist.hasNext;
      String? sessionId = playlist.sessionId;

      final items = <DownloadVideoInfo>[];
      var truncated = false;
      while (true) {
        for (final item in batch) {
          final videoId = _extractVideoId(item.url);
          if (videoId == null) continue;
          if (items.length >= _maxPlaylistItems) {
            truncated = true;
            break;
          }
          items.add(
            DownloadVideoInfo(
              id: videoId,
              title: item.name,
              channel: item.uploaderName ?? '',
              duration: item.duration != null && item.duration! > 0
                  ? Duration(seconds: item.duration!)
                  : null,
              thumbnailUrls: _thumbnailUrls(videoId),
            ),
          );
        }
        if (truncated || !hasNext || sessionId == null) break;
        final next = await _extractor.loadMore(sessionId);
        batch = next.items;
        hasNext = next.hasNext;
        sessionId = next.sessionId;
      }
      _log('fetchPlaylist: ${items.length} vídeos listados');
      if (items.isEmpty) {
        throw const DownloadException('A playlist não retornou vídeos.');
      }
      return DownloadPlaylist(
        title: playlist.name,
        author: playlist.uploaderName,
        items: items,
        truncated: truncated,
      );
    } on DownloadException {
      rethrow;
    } catch (e, st) {
      _log('fetchPlaylist erro: $e\n$st');
      throw const DownloadException(
        'Não foi possível listar a playlist. Ela precisa ser pública ou '
        'não listada.',
      );
    }
  }

  /// Indica se a biblioteca já tem uma faixa com o mesmo título e artista
  /// (ignora maiúsculas e espaços extras).
  static bool isDuplicate(
    Iterable<MusicTrack> library,
    String title,
    String artist,
  ) {
    String normalize(String s) =>
        s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final t = normalize(title);
    final a = normalize(artist);
    return library.any(
      (track) => normalize(track.title) == t && normalize(track.artist) == a,
    );
  }

  /// Sugere tags a partir do título e do canal do vídeo.
  static DownloadTags suggestTags(DownloadVideoInfo info) {
    final channel = info.channel
        .replaceFirst(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*VEVO$', caseSensitive: false), '')
        .trim();

    var title = info.title.replaceAll(_noiseGroup, '').trim();
    var artist = channel;

    // Padrão comum "Artista - Título": o canal costuma não ser o artista.
    final separator = title.indexOf(' - ');
    if (separator > 0) {
      artist = title.substring(0, separator).trim();
      title = title.substring(separator + 3).trim();
    }

    return DownloadTags(
      title: title.isEmpty ? info.title : title,
      artist: artist,
      album: '',
    );
  }

  // ── Download ──────────────────────────────────────────────────────────────

  static final Map<String, Completer<void>> _cancelSignals = {};

  /// Baixa o áudio (formato nativo, m4a ou webm) e a capa para o cache do
  /// app. [onProgress] recebe a fração (null se o plugin não informar) e os
  /// bytes já gravados no cache.
  static Future<DownloadedMedia> download(
    DownloadVideoInfo info, {
    required void Function(double? fraction, int bytes) onProgress,
  }) async {
    final cancelSignal = Completer<void>();
    _cancelSignals[info.id] = cancelSignal;
    Timer? poller;
    Directory? outDir;
    var succeeded = false;
    try {
      await Ytdlp.init();
      final cacheDir = await getTemporaryDirectory();
      final dir = Directory('${cacheDir.path}/mw_dl');
      outDir = dir;
      await dir.create(recursive: true);
      await _cleanFiles(dir, info.id);

      // O plugin nem sempre informa progresso; o tamanho dos arquivos no
      // cache é a fonte confiável de andamento.
      double? fraction;
      poller = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => onProgress(fraction, _downloadedBytes(dir, info.id)),
      );

      final download = Ytdlp.downloadAudio(
        url: _canonicalUrl(info.id),
        outputDir: dir.path,
        taskId: info.id,
        onProgress: (p) {
          final value = p.fraction;
          if (value != null) fraction = value.clamp(0.0, 1.0).toDouble();
        },
      );
      final path = await Future.any<String>([
        download,
        cancelSignal.future.then<String>(
          (_) => throw const DownloadCancelledException(),
        ),
      ]);

      // m4a/mp4 é AAC e pode ser copiado sem recodificar; webm vira AAC/MP3 ao salvar.
      final ext = path.split('.').last.toLowerCase();
      final thumbnail = await _downloadThumbnail(info.thumbnailUrls, info.id);
      succeeded = true;
      return DownloadedMedia(
        audioPath: path,
        thumbnailPath: thumbnail,
        isAacMp4: ext == 'm4a' || ext == 'mp4',
      );
    } on DownloadCancelledException {
      rethrow;
    } catch (e, st) {
      // O cancelamento pode fazer o plugin lançar erro antes do nosso sinal.
      if (cancelSignal.isCompleted) throw const DownloadCancelledException();
      _log('download erro: $e\n$st');
      throw const DownloadException(
        'Falha ao baixar o áudio. Tente novamente.',
      );
    } finally {
      poller?.cancel();
      _cancelSignals.remove(info.id);
      if (!succeeded && outDir != null) await _cleanFiles(outDir, info.id);
    }
  }

  /// Cancela o download em andamento do vídeo [id].
  static Future<void> cancel(String id) async {
    final signal = _cancelSignals[id];
    if (signal != null && !signal.isCompleted) signal.complete();
    try {
      await Ytdlp.cancel(id);
    } catch (_) {}
  }

  static int _downloadedBytes(Directory dir, String id) {
    var total = 0;
    try {
      for (final entity in dir.listSync()) {
        if (entity is File && entity.uri.pathSegments.last.startsWith(id)) {
          total += entity.lengthSync();
        }
      }
    } catch (_) {}
    return total;
  }

  /// Remove restos (.part, arquivos parciais) de um vídeo no cache.
  static Future<void> _cleanFiles(Directory dir, String id) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.uri.pathSegments.last.startsWith(id)) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  static Future<String?> _downloadThumbnail(
    List<String> urls,
    String videoId,
  ) async {
    final cacheDir = await getTemporaryDirectory();
    final file = File('${cacheDir.path}/mw_dl_${videoId}_thumb.jpg');
    final client = HttpClient();
    try {
      for (final url in urls) {
        try {
          final request = await client.getUrl(Uri.parse(url));
          final response = await request.close();
          if (response.statusCode != 200) {
            await response.drain<void>();
            continue;
          }
          await response.pipe(file.openWrite());
          return file.path;
        } catch (_) {
          // Tenta a próxima URL (ex: maxres inexistente para o vídeo).
        }
      }
    } finally {
      client.close();
    }
    return null;
  }

  // ── Salvar na biblioteca ──────────────────────────────────────────────────

  /// Indica se este build do ffmpeg consegue gerar MP3.
  static Future<bool> mp3Available() => FfmpegService.supportsMp3();

  /// Grava tags e capa no arquivo (.m4a ou .mp3) e o envia para a pasta raiz
  /// da biblioteca via SAF. Retorna o caminho final do arquivo.
  static Future<String> saveToLibrary({
    required DownloadedMedia media,
    required DownloadTags tags,
    required String rootDirectory,
    required DownloadFormat format,
  }) async {
    final folderUri = await SafService.ensureAccess();
    if (folderUri == null) {
      throw const DownloadException('Acesso à pasta negado. Salvar cancelado.');
    }

    final root = rootDirectory.endsWith('/')
        ? rootDirectory.substring(0, rootDirectory.length - 1)
        : rootDirectory;
    final fileName = _uniqueFileName(root, tags, format.extension);

    final tempPath = await FfmpegService.buildTaggedAudio(
      inputPath: media.audioPath,
      outputName: fileName,
      title: tags.title,
      artist: tags.artist,
      album: tags.album,
      coverPath: media.thumbnailPath,
      copyAudio: media.isAacMp4,
      mp3: format == DownloadFormat.mp3,
    );
    if (tempPath == null) {
      throw const DownloadException('Erro ao processar o arquivo de áudio.');
    }

    final copied = await SafService.copyTempToSaf(
      tempPath: tempPath,
      targetFileName: fileName,
      folderUri: folderUri,
    );
    await _deleteQuietly(tempPath);
    if (!copied) {
      throw const DownloadException('Erro ao salvar o arquivo na pasta.');
    }

    final finalPath = '$root/$fileName';
    if (!await File(finalPath).exists()) {
      // A pasta concedida via SAF não é a mesma da raiz da biblioteca.
      throw const DownloadException(
        'O arquivo não apareceu na pasta raiz da biblioteca. '
        'Confira a pasta concedida ao app.',
      );
    }
    return finalPath;
  }

  /// Remove os arquivos temporários de um download descartado ou concluído.
  static Future<void> discard(DownloadedMedia media) async {
    await _deleteQuietly(media.audioPath);
    await _deleteQuietly(media.thumbnailPath);
  }

  static String _uniqueFileName(
    String root,
    DownloadTags tags,
    String extension,
  ) {
    final artist = tags.artist.replaceAll(';', ',');
    var base = artist.isEmpty ? tags.title : '$artist - ${tags.title}';
    base = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (base.length > 120) base = base.substring(0, 120).trim();
    if (base.isEmpty) base = 'Download';

    var name = '$base.$extension';
    var counter = 2;
    while (File('$root/$name').existsSync()) {
      name = '$base ($counter).$extension';
      counter++;
    }
    return name;
  }

  static Future<void> _deleteQuietly(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
