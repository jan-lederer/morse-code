import 'package:dit_morse/signal_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'queued dash retains 300ms even when released soon after audio starts',
    (tester) async {
      final events = <(bool, int)>[];
      final start = tester.binding.clock.now();
      final feedback = SignalFeedback((enabled) {
        events.add((
          enabled,
          tester.binding.clock.now().difference(start).inMilliseconds,
        ));
      });
      final dot = feedback.press();
      await tester.pump(const Duration(milliseconds: 5));
      feedback.release(dot, dash: false);
      await tester.pump(const Duration(milliseconds: 20));
      final dash = feedback.press();
      await tester.pump(const Duration(milliseconds: 175));
      expect(events, [(true, 0), (false, 100), (true, 200)]);
      await tester.pump(const Duration(milliseconds: 55));
      feedback.release(dash, dash: true);
      await tester.pump(const Duration(milliseconds: 244));
      expect(events.last, (true, 200));
      await tester.pump(const Duration(milliseconds: 1));
      expect(events.last, (false, 500));
      await tester.pump(const Duration(milliseconds: 100));
      feedback.cancel();
    },
  );

  testWidgets('rapid released signals keep their order and full silent gaps', (
    tester,
  ) async {
    final events = <(bool, int)>[];
    final start = tester.binding.clock.now();
    final feedback = SignalFeedback((enabled) {
      events.add((
        enabled,
        tester.binding.clock.now().difference(start).inMilliseconds,
      ));
    });
    for (final dash in [false, false, true]) {
      final signal = feedback.press();
      feedback.release(signal, dash: dash);
      await tester.pump(const Duration(milliseconds: 5));
    }
    await tester.pump(const Duration(milliseconds: 785));
    expect(events, [
      (true, 0),
      (false, 100),
      (true, 200),
      (false, 300),
      (true, 400),
      (false, 700),
    ]);
    feedback.cancel();
  });

  testWidgets(
    'cancelling during silence clears queued tones and allows fresh input',
    (tester) async {
      final tones = <bool>[];
      final feedback = SignalFeedback(tones.add);
      feedback.release(feedback.press(), dash: false);
      feedback.release(feedback.press(), dash: true);
      await tester.pump(const Duration(milliseconds: 150));
      feedback.cancel();
      final count = tones.length;
      await tester.pump(const Duration(seconds: 1));
      expect(tones.length, count);
      final fresh = feedback.press();
      expect(tones.last, isTrue);
      feedback.release(fresh, dash: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tones.last, isFalse);
      feedback.cancel();
    },
  );
}
