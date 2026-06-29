import 'dart:io';

import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/services/ffmpeg_service.dart';
import 'package:music_wave_player/services/saf_service.dart';

/// Resultado de uma operação de edição de faixa.
/// Elimina o acoplamento com [BuildContext] no repositório.
sealed class TrackEditResult {
  const TrackEditResult();
  const factory TrackEditResult.success(MusicTrack updatedTrack) =
      TrackEditSuccess;
  const factory TrackEditResult.failure(String reason) = TrackEditFailure;
}

class TrackEditSuccess extends TrackEditResult {
  final MusicTrack updatedTrack;
  const TrackEditSuccess(this.updatedTrack);
}

class TrackEditFailure extends TrackEditResult {
  final String reason;
  const TrackEditFailure(this.reason);
}

/// Responsável pelas operações de leitura e escrita de faixas no banco de dados.
///
/// Não mantém estado interno — opera diretamente no banco e retorna resultados.
/// No Riverpod, as operações que afetam a lista de faixas serão chamadas pelo
/// [IndexingNotifier], que mantém o estado atualizado.
class TrackRepository {
  TrackRepository._();

  // ── Avaliação ─────────────────────────────────────────────────────────────

  /// Persiste a avaliação no banco e retorna a faixa atualizada.
  static Future<MusicTrack> setRating(MusicTrack track, double rating) async {
    await MusicDatabase.instance.updateRating(track.id!, rating);
    return track.copyWith(rating: rating);
  }

  // ── Ocultar / Reexibir ────────────────────────────────────────────────────

  static Future<void> hideTracks(List<int> ids) async {
    if (ids.isEmpty) return;
    await MusicDatabase.instance.setHidden(ids, hidden: true);
  }

  static Future<void> unhideTracks(List<int> ids) async {
    if (ids.isEmpty) return;
    await MusicDatabase.instance.setHidden(ids, hidden: false);
  }

  static Future<void> unhideAllTracks() async {
    await MusicDatabase.instance.unhideAll();
  }

  // ── Edição de metadados ───────────────────────────────────────────────────

  /// Edita os metadados de uma faixa via ffmpeg + SAF.
  ///
  /// Retorna [TrackEditSuccess] com a faixa atualizada, ou [TrackEditFailure]
  /// com a mensagem de erro — sem dependência de [BuildContext].
  static Future<TrackEditResult> editTrack({
    required MusicTrack track,
    required String newTitle,
    required String newArtist,
    required String newAlbum,
  }) async {
    final folderUri = await SafService.ensureAccess();
    if (folderUri == null) {
      return const TrackEditFailure('Acesso à pasta negado. Edição cancelada.');
    }

    final tempPath = await FfmpegService.writeMetadata(
      inputPath: track.path,
      title: newTitle,
      artist: newArtist,
      album: newAlbum,
    );
    if (tempPath == null) {
      return const TrackEditFailure(
        'Erro ao processar o arquivo. Tente novamente.',
      );
    }

    final fileName = track.path.split('/').last;
    final copied = await SafService.copyTempToSaf(
      tempPath: tempPath,
      targetFileName: fileName,
      folderUri: folderUri,
    );

    try {
      await File(tempPath).delete();
    } catch (_) {}

    if (!copied) {
      return const TrackEditFailure(
        'Erro ao salvar o arquivo. Tente novamente.',
      );
    }

    await MusicDatabase.instance.updateTrack(
      id: track.id!,
      title: newTitle,
      artist: newArtist,
      album: newAlbum,
    );

    final updatedTrack = track.copyWith(
      title: newTitle,
      artist: newArtist,
      album: newAlbum,
      isEdited: true,
    );

    return TrackEditSuccess(updatedTrack);
  }
}
