import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dit_morse/main.dart';
import 'package:dit_morse/morse.dart';
import 'package:dit_morse/recognition_workspace.dart';
import 'package:dit_morse/practice_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('studio.dit/device');
  const capture = bool.fromEnvironment('CAPTURE_RECOGNITION');
  final calls = <MethodCall>[];
  final answers = <(String, bool)>[];
  String? saved;
  Future<int>? patternReady;

  setUpAll(() async {
    if (!capture) return;
    for (final family in ['Roboto', 'Ahem', 'MaterialIcons']) {
      final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
      final file = File(
        family == 'MaterialIcons'
            ? '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
            : '$root/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
      );
      if (file.existsSync()) {
        await (FontLoader(family)..addFont(
              Future.value(ByteData.sublistView(await file.readAsBytes())),
            ))
            .load();
      }
    }
  });
  setUp(() {
    calls.clear();
    answers.clear();
    saved = null;
    patternReady = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'version') return '1.0.0 (10)';
          if (call.method == 'playPattern') {
            return await (patternReady ?? Future.value(150));
          }
          if (call.method == 'save') saved = call.arguments as String;
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<void> open(
    WidgetTester tester, {
    String group = 'ET',
    bool choices = false,
    bool sound = false,
    bool vibration = false,
    bool hideHint = false,
    Size size = const Size(390, 844),
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: dark ? Brightness.dark : Brightness.light,
          colorSchemeSeed: coral,
          fontFamily: 'Roboto',
        ),
        home: Scaffold(
          body: RecognitionWorkspace(
            groups: const {
              'A': 'Only A',
              'ET': 'Your first signals',
              '0123456789': 'Numbers',
              '@words': 'Real words',
              '@sentences': 'Sentences',
            },
            initialGroup: group,
            fourChoices: choices,
            sound: sound,
            vibration: vibration,
            hideHint: hideHint,
            dark: dark,
            onAnswer: (letter, correct) => answers.add((letter, correct)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    calls.clear();
  }

  String question(WidgetTester tester) => decode(
    tester
        .widget<Text>(find.byKey(const ValueKey('recognition-code')))
        .data!
        .replaceAll('·', '.')
        .replaceAll('−', '-'),
  );
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> mode(WidgetTester tester, String label) async {
    final sending = label == 'Send signals';
    await tap(
      tester,
      find.byKey(ValueKey('practice-direction-${sending ? 'send' : 'listen'}')),
    );
    await tester.pumpAndSettle();
    final choices = label == '4 choices';
    await tester.tap(find.text(choices ? '4' : 'Type').last);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  final answer = find.byKey(const ValueKey('recognition-answer'));

  testWidgets(
    'typed answers retry, normalize lowercase, score once and advance after 650ms',
    (tester) async {
      await open(tester);
      final target = question(tester);
      await tap(tester, find.text('Check'));
      expect(answers, isEmpty);
      await tester.enterText(answer, 'z');
      await tap(tester, find.text('Check'));
      expect(answers, [(target, false)]);
      expect(question(tester), target);
      await tester.pump(const Duration(seconds: 1));
      expect(question(tester), target);
      await tester.enterText(answer, target.toLowerCase());
      await tap(tester, find.text('Check'));
      expect(answers, [(target, false), (target, true)]);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('practice-correct')))
            .data,
        '1',
      );
      expect(find.text('50%'), findsOneWidget);
      await tap(tester, find.text('Check'));
      expect(answers.length, 2);
      await tester.pump(const Duration(milliseconds: 649));
      expect(question(tester), target);
      await tester.pump(const Duration(milliseconds: 1));
      expect(question(tester), isNot(target));
      expect(tester.widget<TextField>(answer).controller!.text, isEmpty);
      await close(tester);
    },
  );

  testWidgets(
    'keyboard stays open after Enter and automatic advance, but stays closed after dismissal',
    (tester) async {
      await open(tester);
      final target = question(tester);
      await tester.enterText(answer, target);
      tester.view.viewInsets = const FakeViewPadding(bottom: 430);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.widget<TextField>(answer).focusNode!.hasFocus, isTrue);
      expect(tester.widget<TextField>(answer).enabled, isNot(false));
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.pump(const Duration(milliseconds: 650));
      expect(tester.widget<TextField>(answer).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(answer, question(tester));
      await tap(tester, find.text('Check'));
      tester.testTextInput.hide();
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      expect(tester.testTextInput.isVisible, isFalse);
      await close(tester);
    },
  );

  testWidgets(
    'four unique choices fill the width in a large 2x2 grid and auto-advance',
    (tester) async {
      await open(tester, choices: true);
      final target = question(tester);
      final buttons = find.byType(OutlinedButton);
      final labels = tester
          .widgetList<OutlinedButton>(buttons)
          .map((b) => (b.child as Text).data!)
          .toList();
      expect(labels.toSet().length, 4);
      expect(labels, contains(target));
      final grid = tester.getRect(
        find.byKey(const ValueKey('recognition-grid')),
      );
      final rects = List.generate(4, (i) => tester.getRect(buttons.at(i)));
      expect(rects[0].left, grid.left);
      expect(rects[1].right, grid.right);
      expect(rects[2].left, grid.left);
      expect(rects[3].right, grid.right);
      expect(rects[0].top, rects[1].top);
      expect(rects[2].top, rects[3].top);
      expect(rects[2].top, greaterThan(rects[0].bottom));
      expect(rects.every((r) => r.height >= 72), isTrue);
      final wrong = labels.firstWhere((c) => c != target);
      await tap(tester, find.byKey(ValueKey('recognition-choice-$wrong')));
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(ValueKey('recognition-choice-$wrong')),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, find.byKey(ValueKey('recognition-choice-$target')));
      await tester.pump(const Duration(milliseconds: 650));
      expect(question(tester), isNot(target));
      expect(answers, [(target, false), (target, true)]);
      await close(tester);
    },
  );

  testWidgets('number group uses numeric questions and four numeric choices', (
    tester,
  ) async {
    await open(tester, choices: true);
    await tap(tester, find.byKey(const ValueKey('practice-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Numbers').last);
    await tester.pumpAndSettle();
    expect('0123456789', contains(question(tester)));
    expect(
      tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .every((b) => '0123456789'.contains((b.child as Text).data!)),
      isTrue,
    );
    await close(tester);
  });

  testWidgets(
    'word and sentence sets build phrase questions with four answers',
    (tester) async {
      for (final group in ['@words', '@sentences']) {
        await open(tester, group: group, choices: true);
        expect(find.text('NAME THIS WORD OR SENTENCE'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('recognition-code')))
              .data,
          contains(' '),
        );
        expect(find.byType(OutlinedButton), findsNWidgets(4));
        expect(tester.takeException(), isNull);
        await close(tester);
      }
    },
  );

  test('phrase banks contain 100 to 200 entries each', () {
    expect(practiceWords.length, inInclusiveRange(100, 200));
    expect(practiceSentences.length, inInclusiveRange(100, 200));
    expect(practiceWords.toSet().length, practiceWords.length);
    expect(practiceSentences.toSet().length, practiceSentences.length);
  });

  testWidgets('typed phrase answers accept complete words and sentences', (
    tester,
  ) async {
    for (final group in ['@words', '@sentences']) {
      await open(tester, group: group);
      final shown = tester
          .widget<Text>(find.byKey(const ValueKey('recognition-code')))
          .data!
          .replaceAll('·', '.')
          .replaceAll('−', '-');
      final pool = group == '@words' ? practiceWords : practiceSentences;
      final expected = pool.firstWhere(
        (phrase) =>
            phrase
                .split('')
                .where(morse.containsKey)
                .map((letter) => morse[letter]!)
                .join(' ')
                .replaceAll(' ', '') ==
            shown.replaceAll(' ', ''),
      );
      await tester.enterText(answer, expected.toLowerCase());
      await tap(tester, find.text('Check'));
      expect(answers.last, (
        expected.split('').where(morse.containsKey).last,
        true,
      ));
      await close(tester);
    }
  });

  testWidgets('first playback sends one complete synchronized device pattern', (
    tester,
  ) async {
    await open(tester, group: 'A', sound: true, vibration: true);
    await tap(tester, find.text('Listen'));
    final patterns = calls.where((c) => c.method == 'playPattern').toList();
    expect(patterns.length, 1);
    expect(patterns.single.arguments, {
      'code': '.-',
      'sound': true,
      'vibration': true,
    });
    Color? light() =>
        (tester
                    .widget<Container>(
                      find.byKey(const ValueKey('recognition-light')),
                    )
                    .decoration
                as BoxDecoration)
            .color;
    final off = light();
    await tester.pump(const Duration(milliseconds: 149));
    expect(light(), off);
    await tester.pump(const Duration(milliseconds: 1));
    expect(light(), coral);
    await tester.pump(const Duration(milliseconds: 100));
    expect(light(), off);
    await tester.pump(const Duration(milliseconds: 100));
    expect(light(), coral);
    await tester.pump(const Duration(milliseconds: 300));
    expect(light(), off);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Listen'), findsOneWidget);
    expect(calls.where((c) => c.method == 'vibrate'), isEmpty);
    expect(
      calls.where((c) => c.method == 'tone' && c.arguments == true),
      isEmpty,
    );
    await close(tester);
  });

  testWidgets('cold preparation can be cancelled without a late first pulse', (
    tester,
  ) async {
    final ready = Completer<int>();
    patternReady = ready.future;
    await open(tester, group: 'A', sound: true, vibration: true);
    await tap(tester, find.text('Listen'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls.where((c) => c.method == 'playPattern').length, 1);
    expect(calls.where((c) => c.method == 'vibrate'), isEmpty);
    await tap(tester, find.text('Stop'));
    final stopCount = calls.where((c) => c.method == 'stopPattern').length;
    ready.complete(150);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Listen'), findsOneWidget);
    expect(calls.where((c) => c.method == 'stopPattern').length, stopCount);
    expect(calls.where((c) => c.method == 'playPattern').length, 1);
    await close(tester);
  });

  testWidgets('failed device preparation resets playback to allow retry', (
    tester,
  ) async {
    patternReady = Future.value(-1);
    await open(tester, group: 'A', sound: true);
    await tap(tester, find.text('Listen'));
    expect(find.text('Listen'), findsOneWidget);
    expect(calls.where((c) => c.method == 'stopPattern'), isNotEmpty);
    await close(tester);
  });

  testWidgets(
    'same eye icon hides the prompt and preserves hidden state across questions',
    (tester) async {
      await open(tester, choices: true, sound: true);
      await tap(tester, find.byTooltip('Hide hint'));
      expect(find.byKey(const ValueKey('recognition-code')), findsNothing);
      expect(find.byTooltip('Show hint'), findsOneWidget);
      await tap(tester, find.byTooltip('Skip letter'));
      expect(find.byKey(const ValueKey('recognition-code')), findsNothing);
      await close(tester);
    },
  );

  for (final action in ['stop', 'background', 'dispose', 'mode', 'group']) {
    testWidgets('$action handles playback and pending advancement safely', (
      tester,
    ) async {
      await open(tester, choices: true, sound: true, vibration: true);
      final target = question(tester);
      await tap(tester, find.byKey(ValueKey('recognition-choice-$target')));
      if (action == 'mode') {
        await mode(tester, 'Type an answer');
      } else if (action == 'group') {
        await tap(tester, find.byKey(const ValueKey('practice-group')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Numbers').last);
        await tester.pumpAndSettle();
      } else if (action == 'dispose') {
        await close(tester);
        return;
      } else if (action == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
      } else {
        await tap(tester, find.text('Listen'));
        await tap(tester, find.text('Stop'));
      }
      if (action == 'mode' || action == 'group') {
        final changed = question(tester);
        await tester.pump(const Duration(milliseconds: 700));
        expect(question(tester), changed);
      }
      final count = answers.length;
      if (action == 'background') {
        await tester.pump(const Duration(seconds: 2));
        expect(answers.length, count);
        expect(question(tester), target);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      await close(tester);
      expect(calls.where((c) => c.method == 'tone').last.arguments, isFalse);
      expect(calls.where((c) => c.method == 'cancelVibration'), isNotEmpty);
    });
  }

  testWidgets(
    'Practice switches modes in place with shared hint/settings and visible version',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const DitApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practice').last);
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('Hide hint'));
      await mode(tester, 'Type an answer');
      expect(find.byTooltip('Show hint'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
      await tap(tester, find.byTooltip('Show hint'));
      final target = question(tester);
      await tester.enterText(answer, target);
      await tap(tester, find.text('Check'));
      final data = jsonDecode(saved!) as Map<String, dynamic>;
      expect(data['correct'], 1);
      expect(data['learned'], contains(target));
      await tap(tester, find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Version 1.0.0 (10)'), findsOneWidget);
      final before = question(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(question(tester), before);
      await tap(tester, find.text('Got it'));
      await tester.pumpAndSettle();
      await mode(tester, 'Send signals');
      expect(find.byKey(const ValueKey('touch-morse-key')), findsOneWidget);
      expect(find.byTooltip('Hide hint'), findsOneWidget);
      await tester.tap(find.text('Learn').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practice').last);
      await tester.pumpAndSettle();
      await tap(tester, find.text('4'));
      await tester.pumpAndSettle();
      expect(find.byType(OutlinedButton), findsNWidgets(4));
      expect(find.text('Practice').last, findsOneWidget);
      if (capture) {
        final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('artifacts/recognize-unified-four-choices.png')
              .writeAsBytes(png!.buffer.asUint8List());
        });
      }
      await close(tester);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('unified recognition layout and keyboard fit at $size', (
      tester,
    ) async {
      await open(tester, choices: true, size: size, dark: true);
      expect(tester.takeException(), isNull);
      if (capture && size.width == 390) {
        final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('artifacts/recognize-grid-layout.png')
              .writeAsBytes(png!.buffer.asUint8List());
        });
      }
      await mode(tester, 'Type an answer');
      tester.view.viewInsets = FakeViewPadding(bottom: size.height / 2);
      await tester.pumpAndSettle();
      await tap(tester, answer);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await close(tester);
    });
  }
}
