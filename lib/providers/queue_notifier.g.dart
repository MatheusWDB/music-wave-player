// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$queueNotifierHash() => r'25fe1498b13b3fc9e2ffbae7ac310358761e51ce';

/// Estado e operações da fila de reprodução. Substitui o antigo
/// [QueueManager] — síncrono, mas com persistência própria em
/// SharedPreferences (ver [_persist]/[restoreOrRegenerate]), já que a
/// fila deixou de ser só reconstruída a partir das faixas indexadas a
/// cada carregamento do app.
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
