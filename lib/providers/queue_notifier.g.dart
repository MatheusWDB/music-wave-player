// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$queueNotifierHash() => r'5cae2899df4e81e4d8dd85772b534151aea7dcd0';

/// Estado e operações da fila de reprodução, com persistência própria em
/// SharedPreferences (ver [_persist]/[restoreOrRegenerate]).
///
/// Copied from [QueueNotifier].
@ProviderFor(QueueNotifier)
final queueNotifierProvider =
    NotifierProvider<QueueNotifier, QueueState>.internal(
      QueueNotifier.new,
      name: r'queueNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$queueNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$QueueNotifier = Notifier<QueueState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
