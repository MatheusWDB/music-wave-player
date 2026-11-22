import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/services/background_task_manager.dart';
import 'package:music_wave_player/services/saf_service.dart';
import 'package:music_wave_player/services/track_file_namer.dart';

class LibraryRenameResult {
  const LibraryRenameResult({
    required this.renamed,
    required this.alreadyStandard,
    required this.failed,
    required this.cancelled,
  });

  final int renamed;
  final int alreadyStandard;
  final int failed;
  final bool cancelled;
}

/// Renomeação prevista de um arquivo (só os nomes, sem o diretório).
class PendingRename {
  const PendingRename(this.from, this.to);

  final String from;
  final String to;
}

/// Renomeia os arquivos da biblioteca para "Primeiro Artista - Título.ext"
/// usando as tags já salvas no banco; não altera as tags.
class LibraryRenameService {
  LibraryRenameService._();

  /// Arquivos que mudariam de nome, para o diálogo de confirmação.
  static List<PendingRename> pending(List<MusicTrack> tracks) {
    final result = <PendingRename>[];
    for (final track in tracks) {
      final newName = _targetName(track);
      if (newName != null) {
        result.add(PendingRename(track.path.split('/').last, newName));
      }
    }
    return result;
  }

  static String? _targetName(MusicTrack track) {
    final fileName = track.path.split('/').last;
    final dir = track.path.substring(
      0,
      track.path.length - fileName.length - 1,
    );
    return TrackFileNamer.targetFileName(
      dir: dir,
      currentName: fileName,
      artist: track.artist,
      title: track.title,
    );
  }

  /// Renomeia uma faixa por vez. Cancelar mantém o que já foi renomeado;
  /// rodar de novo continua de onde parou.
  static Future<LibraryRenameResult> run({
    required List<MusicTrack> tracks,
    required String rootDirectory,
    required String folderUri,
    required TaskCancelToken cancelToken,
    required void Function(int done, int total) onProgress,
  }) async {
    var renamed = 0;
    var alreadyStandard = 0;
    var failed = 0;
    var cancelled = false;

    for (var i = 0; i < tracks.length; i++) {
      if (cancelToken.isCancelled) {
        cancelled = true;
        break;
      }
      onProgress(i, tracks.length);

      final track = tracks[i];
      final newName = _targetName(track);
      final relativeDir = TrackFileNamer.relativeDir(track.path, rootDirectory);
      if (newName == null) {
        alreadyStandard++;
        continue;
      }
      if (relativeDir == null || track.id == null) {
        failed++;
        continue;
      }

      final fileName = track.path.split('/').last;
      final dir = track.path.substring(
        0,
        track.path.length - fileName.length - 1,
      );
      final actualName = await SafService.renameFile(
        folderUri: folderUri,
        relativeDir: relativeDir,
        oldFileName: fileName,
        newFileName: newName,
      );
      if (actualName == null) {
        failed++;
        continue;
      }

      await MusicDatabase.instance.updatePath(track.id!, '$dir/$actualName');
      renamed++;
    }

    onProgress(tracks.length, tracks.length);
    return LibraryRenameResult(
      renamed: renamed,
      alreadyStandard: alreadyStandard,
      failed: failed,
      cancelled: cancelled,
    );
  }
}
