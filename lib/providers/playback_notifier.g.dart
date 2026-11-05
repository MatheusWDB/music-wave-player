// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playbackNotifierHash() => r'd2ef96d8ed9661bd4ca2714279297395517416e6';

/// Coordena as ações de reprodução: play, pause, next, previous, repeat.
/// Substitui o antigo [PlaybackController] — depende de [QueueNotifier]
/// para navegação na fila e de [musicAudioHandlerProvider] para controle
/// do player de áudio.
///
/// Copied from [PlaybackNotifier].
@ProviderFor(PlaybackNotifier)
final playbackNotifierProvider =
    AsyncNotifierProvider<PlaybackNotifier, PlaybackState>.internal(
      PlaybackNotifier.new,
      name: r'playbackNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$playbackNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PlaybackNotifier = AsyncNotifier<PlaybackState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
