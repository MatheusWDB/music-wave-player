// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equalizer_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$equalizerNotifierHash() => r'b6a082dd9cb33198e7f7d2e041b78e4d931b9d10';

/// Gerencia o estado do equalizador gráfico: 10 bandas, presets prontos e
/// persistência em [SharedPreferences]. Substitui o antigo [EqualizerService].
///
/// Copied from [EqualizerNotifier].
@ProviderFor(EqualizerNotifier)
final equalizerNotifierProvider =
    AsyncNotifierProvider<EqualizerNotifier, EqualizerState>.internal(
      EqualizerNotifier.new,
      name: r'equalizerNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$equalizerNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$EqualizerNotifier = AsyncNotifier<EqualizerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
