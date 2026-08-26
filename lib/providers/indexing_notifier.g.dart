// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexing_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$indexingNotifierHash() => r'2ae072052e97f736881de55cd2fba5e1d3560803';

/// Gerencia a biblioteca de faixas indexadas: diretório raiz, varredura,
/// ocultar/reexibir, avaliação e edição de metadados. Substitui a parte
/// de indexação do antigo [Configuration].
///
/// Copied from [IndexingNotifier].
@ProviderFor(IndexingNotifier)
final indexingNotifierProvider =
    AsyncNotifierProvider<IndexingNotifier, IndexingState>.internal(
      IndexingNotifier.new,
      name: r'indexingNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$indexingNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$IndexingNotifier = AsyncNotifier<IndexingState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
