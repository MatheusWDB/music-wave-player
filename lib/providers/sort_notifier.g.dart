// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sort_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sortNotifierHash() => r'1dd47b6d39b6c5442c32385276111df2df2d27b5';

/// Gerencia as preferências de ordenação por aba, com persistência em
/// [SharedPreferences]. Substitui a parte de estado do antigo [SortService]
/// — a aplicação da ordenação em si continua em [SortService.apply],
/// que é uma função pura sem estado.
///
/// Copied from [SortNotifier].
@ProviderFor(SortNotifier)
final sortNotifierProvider =
    AsyncNotifierProvider<SortNotifier, SortState>.internal(
      SortNotifier.new,
      name: r'sortNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sortNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SortNotifier = AsyncNotifier<SortState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
