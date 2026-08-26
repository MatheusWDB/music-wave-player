// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_track_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentTrackHash() => r'1f1f955c562bfd1209edca07da58a712990b6882';

/// Faixa atualmente carregada, derivada do cruzamento entre
/// [PlaybackNotifier] (id da última faixa tocada) e [IndexingNotifier]
/// (lista de faixas indexadas). Substitui o getter `Configuration.currentTrack`.
///
/// Copied from [currentTrack].
@ProviderFor(currentTrack)
final currentTrackProvider = AutoDisposeProvider<MusicTrack?>.internal(
  currentTrack,
  name: r'currentTrackProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentTrackHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentTrackRef = AutoDisposeProviderRef<MusicTrack?>;
String _$recentlyPlayedTracksHash() =>
    r'8d942b5e729c1c28db9af6ff491f219fe3dcd38c';

/// Lista de faixas reproduzidas recentemente, na ordem do histórico.
/// Substitui o getter `Configuration.recentlyPlayedTracks`.
///
/// Copied from [recentlyPlayedTracks].
@ProviderFor(recentlyPlayedTracks)
final recentlyPlayedTracksProvider =
    AutoDisposeProvider<List<MusicTrack>>.internal(
      recentlyPlayedTracks,
      name: r'recentlyPlayedTracksProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recentlyPlayedTracksHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentlyPlayedTracksRef = AutoDisposeProviderRef<List<MusicTrack>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
