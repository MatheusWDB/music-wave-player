// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_settings_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playerSettingsNotifierHash() =>
    r'c60040468f5894451cec5cc6c8c546eb85bc5065';

/// Configurações gerais de reprodução que sobravam soltas no antigo
/// [Configuration]: velocidade (não persistida — mesmo comportamento
/// original, volta a 1.0x a cada abertura do app), crossfade e fade ao
/// pausar/retomar (ambos persistidos).
///
/// Copied from [PlayerSettingsNotifier].
@ProviderFor(PlayerSettingsNotifier)
final playerSettingsNotifierProvider =
    AsyncNotifierProvider<PlayerSettingsNotifier, PlayerSettingsState>.internal(
      PlayerSettingsNotifier.new,
      name: r'playerSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$playerSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PlayerSettingsNotifier = AsyncNotifier<PlayerSettingsState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
