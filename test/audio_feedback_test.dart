import 'dart:convert';

import 'package:dit_morse/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('studio.dit/device');
  final tones = <bool>[];
  var sound = true;
  var vibration = false;

  setUp(() {
    tones.clear();
    sound = true;
    vibration = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'load') {
            return jsonEncode({'sound': sound, 'vibration': vibration});
          }
          if (call.method == 'tone') tones.add(call.arguments as bool);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final key = find.byKey(const ValueKey('touch-morse-key'));

  Future<void> open(WidgetTester tester, {bool practice = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DitApp());
    await tester.pumpAndSettle();
    if (practice) {
      await tester.tap(find.text('Practice').last);
      await tester.pumpAndSettle();
    }
    tones.clear();
  }

  for (final practice in [false, true]) {
    testWidgets(
      '5ms tap has a 100ms tone in ${practice ? 'practice' : 'tree'}',
      (tester) async {
        await open(tester, practice: practice);
        final tap = await tester.startGesture(tester.getCenter(key));
        await tester.pump(const Duration(milliseconds: 5));
        await tap.up();
        await tester.pump();
        expect(tones, [true]);
        expect(find.text('Tap. Hold. Connect.'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 94));
        expect(tones.last, isTrue);
        await tester.pump(const Duration(milliseconds: 1));
        expect(tones, [true, false]);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    for (final pause in [0, 20]) {
      testWidgets(
        'two 5ms taps with ${pause}ms pause play separate dots and decode I in ${practice ? 'practice' : 'tree'}',
        (tester) async {
          await open(tester, practice: practice);
          final first = await tester.startGesture(tester.getCenter(key));
          await tester.pump(const Duration(milliseconds: 5));
          await first.up();
          await tester.pump(Duration(milliseconds: pause));
          final second = await tester.startGesture(tester.getCenter(key));
          await tester.pump(const Duration(milliseconds: 5));
          await second.up();
          await tester.pump();
          expect(tones, [true]);
          expect(find.text('Tap. Hold. Connect.'), findsOneWidget);

          // The second release must not truncate the first dot or restart it.
          await tester.pump(Duration(milliseconds: 89 - pause));
          expect(tones, [true]);
          await tester.pump(const Duration(milliseconds: 1));
          expect(tones, [true, false]);
          await tester.pump(const Duration(milliseconds: 99));
          expect(tones, [true, false]);
          await tester.pump(const Duration(milliseconds: 1));
          expect(tones, [true, false, true]);
          await tester.pump(const Duration(milliseconds: 99));
          expect(tones, [true, false, true]);
          await tester.pump(const Duration(milliseconds: 1));
          expect(tones, [true, false, true, false]);

          await tester.pump(const Duration(milliseconds: 750));
          if (practice) {
            expect(
              tester
                  .widget<Text>(find.byKey(const ValueKey('practice-feedback')))
                  .data,
              'You sent I. Try E again.',
            );
          } else {
            expect(
              tester
                  .widget<Text>(find.byKey(const ValueKey('compact-message')))
                  .data,
              'I',
            );
          }
          expect(tones, [true, false, true, false]);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('short dot then held dash stays audible and decodes A', (
    tester,
  ) async {
    await open(tester);
    final tap = await tester.startGesture(tester.getCenter(key));
    await tester.pump(const Duration(milliseconds: 5));
    await tap.up();
    await tester.pump(const Duration(milliseconds: 195));
    expect(tones, [true, false]);
    final hold = await tester.startGesture(tester.getCenter(key));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tones.last, isTrue);
    await hold.up();
    await tester.pump();
    expect(tones.last, isFalse);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('compact-message'))).data,
      'A',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('rapid dot then hold has a full dot and silent gap', (
    tester,
  ) async {
    await open(tester);
    final tap = await tester.startGesture(tester.getCenter(key));
    await tester.pump(const Duration(milliseconds: 5));
    await tap.up();
    await tester.pump(const Duration(milliseconds: 20));
    final hold = await tester.startGesture(tester.getCenter(key));
    await tester.pump();
    expect(tones.last, isTrue);
    final count = tones.length;
    await tester.pump(const Duration(milliseconds: 75));
    expect(tones.length, count + 1);
    expect(tones.last, isFalse);
    await tester.pump(const Duration(milliseconds: 99));
    expect(tones.last, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tones.last, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await hold.up();
    await tester.pump();
    expect(tones.last, isFalse);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('compact-message'))).data,
      'A',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final action in [
    'cancel',
    'navigate',
    'background',
    'dispose',
    'mute',
  ]) {
    testWidgets('$action stops a pending short tone immediately', (
      tester,
    ) async {
      await open(tester);
      final tap = await tester.startGesture(tester.getCenter(key));
      await tester.pump(const Duration(milliseconds: 5));
      await tap.up();
      await tester.pump(const Duration(milliseconds: 20));
      final queued = await tester.startGesture(tester.getCenter(key));
      if (action == 'cancel') {
        await queued.cancel();
      } else {
        await queued.up();
        await tester.pump();
        expect(tones.last, isTrue);
        switch (action) {
          case 'navigate':
            await tester.tap(find.text('Learn').last);
          case 'background':
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
          case 'dispose':
            await tester.pumpWidget(const SizedBox.shrink());
          case 'mute':
            await tester.tap(find.byTooltip('Settings'));
            await tester.pump();
            await tester.tap(find.byType(Switch).first);
        }
      }
      await tester.pump();
      expect(tones.last, isFalse);
      final count = tones.length;
      await tester.pump(const Duration(milliseconds: 1000));
      expect(tones.length, count);
      await tester.pumpWidget(const SizedBox.shrink());
      if (action == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    });
  }

  testWidgets('saved sound off keeps short taps silent', (tester) async {
    sound = false;
    await open(tester);
    final tap = await tester.startGesture(tester.getCenter(key));
    await tester.pump(const Duration(milliseconds: 5));
    await tap.up();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tones, isNot(contains(true)));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('alphabet previews respect the saved sound setting', (
    tester,
  ) async {
    sound = false;
    final patterns = <Map<Object?, Object?>>[];
    String? saved;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'load') return jsonEncode({'sound': sound});
          if (call.method == 'save') saved = call.arguments as String;
          if (call.method == 'playPattern') {
            patterns.add(Map<Object?, Object?>.from(call.arguments as Map));
            return 0;
          }
          return null;
        });
    await open(tester);
    await tester.tap(find.text('Alphabet').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alphabet-entry-A')));
    await tester.pump();

    expect(patterns, hasLength(1));
    expect(patterns.single['sound'], isFalse);
    expect(
      saved == null || (jsonDecode(saved!) as Map)['sound'] == false,
      isTrue,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('alphabet previews use the saved vibration setting', (
    tester,
  ) async {
    vibration = true;
    final patterns = <Map<Object?, Object?>>[];
    final vibrations = <int>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'load') {
            return jsonEncode({'sound': false, 'vibration': true});
          }
          if (call.method == 'vibrate') vibrations.add(call.arguments as int);
          if (call.method == 'playPattern') {
            patterns.add(Map<Object?, Object?>.from(call.arguments as Map));
            return 0;
          }
          return null;
        });
    await open(tester);
    await tester.tap(find.text('Alphabet').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alphabet-entry-A')));
    await tester.pump();

    expect(vibrations, isEmpty);
    expect(patterns.single['vibration'], isTrue);
    expect(patterns.single['sound'], isFalse);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
