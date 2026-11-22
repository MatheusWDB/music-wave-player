// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$downloadNotifierHash() => r'74c1c9a43a172e3a81a946029b3c0f27d4fad407';

/// Executa os downloads fora das telas: o usuário pode sair de "Baixar
/// músicas" e usar o app enquanto o progresso aparece no banner da tela
/// inicial e na notificação.
///
/// Copied from [DownloadNotifier].
@ProviderFor(DownloadNotifier)
final downloadNotifierProvider =
    NotifierProvider<DownloadNotifier, DownloadState>.internal(
      DownloadNotifier.new,
      name: r'downloadNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$downloadNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DownloadNotifier = Notifier<DownloadState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
