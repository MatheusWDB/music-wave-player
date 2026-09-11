// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timer_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$timerNotifierHash() => r'06ae516d355b6b2698b22e773c7248aa6f5ed882';

/// Gerencia o temporizador de sono: por duração, fim da música atual ou
/// fim da fila. Substitui o antigo [SleepTimerService] — depende de
/// [QueueNotifier] para saber se a faixa atual é a última da fila, e de
/// [musicAudioHandlerProvider] para pausar quando o timer dispara.
///
/// Copied from [TimerNotifier].
@ProviderFor(TimerNotifier)
final timerNotifierProvider =
    NotifierProvider<TimerNotifier, TimerState>.internal(
      TimerNotifier.new,
      name: r'timerNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$timerNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TimerNotifier = Notifier<TimerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
