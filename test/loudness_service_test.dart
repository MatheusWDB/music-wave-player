import 'package:flutter_test/flutter_test.dart';
import 'package:music_wave_player/services/loudness_service.dart';

/// Scanner falso: devolve um resultado por chamada, na ordem da lista.
class _FakeScanner {
  _FakeScanner(this._results);

  final List<double?> _results;
  int calls = 0;

  Future<double?> call(String path) async => _results[calls++];
}

void main() {
  group('LoudnessService.scanVerified', () {
    test(
      'dois scans que concordam: usa o segundo e não escaneia de novo',
      () async {
        final scanner = _FakeScanner([-8.5, -8.4]);

        final result = await LoudnessService.scanVerified(
          'a.m4a',
          scanner: scanner.call,
        );

        expect(result, -8.4);
        expect(scanner.calls, 2);
      },
    );

    test('primeiro scan ruim: o terceiro concorda com o segundo', () async {
      final scanner = _FakeScanner([-24.6, -8.5, -8.4]);

      final result = await LoudnessService.scanVerified(
        'a.m4a',
        scanner: scanner.call,
      );

      expect(result, -8.4);
      expect(scanner.calls, 3);
    });

    test('segundo scan ruim: o terceiro concorda com o primeiro', () async {
      final scanner = _FakeScanner([-8.5, -24.6, -8.4]);

      final result = await LoudnessService.scanVerified(
        'a.m4a',
        scanner: scanner.call,
      );

      expect(result, -8.4);
      expect(scanner.calls, 3);
    });

    test('três scans diferentes: sem consenso, devolve null', () async {
      final scanner = _FakeScanner([-8.5, -15.0, -24.6]);

      final result = await LoudnessService.scanVerified(
        'a.m4a',
        scanner: scanner.call,
      );

      expect(result, isNull);
      expect(scanner.calls, 3);
    });

    test('primeiro scan falha: devolve null sem insistir', () async {
      final scanner = _FakeScanner([null]);

      final result = await LoudnessService.scanVerified(
        'a.m4a',
        scanner: scanner.call,
      );

      expect(result, isNull);
      expect(scanner.calls, 1);
    });

    test(
      'segundo scan falha: o terceiro precisa concordar com o primeiro',
      () async {
        final agreeing = _FakeScanner([-8.5, null, -8.4]);
        final diverging = _FakeScanner([-8.5, null, -24.6]);

        expect(
          await LoudnessService.scanVerified('a.m4a', scanner: agreeing.call),
          -8.4,
        );
        expect(
          await LoudnessService.scanVerified('a.m4a', scanner: diverging.call),
          isNull,
        );
      },
    );
  });
}
