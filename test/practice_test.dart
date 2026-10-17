import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dit_morse/main.dart';
import 'package:dit_morse/morse.dart';

void main() {
  const capture = bool.fromEnvironment('CAPTURE_PRACTICE_PREVIEWS');
  setUpAll(() async {
    if (!capture) return;
    final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
    for (final family in ['Roboto', 'Ahem', 'MaterialIcons']) {
      final file = File(
        family == 'MaterialIcons'
            ? '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
            : '$root/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
      );
      if (file.existsSync()) {
        final loader = FontLoader(family)
          ..addFont(
            Future.value(ByteData.sublistView(await file.readAsBytes())),
          );
        await loader.load();
      }
    }
  });
  Future<void> openPractice(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DitApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
  }

  String target(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('practice-target'))).data!;
  String feedback(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('practice-feedback')))
      .data!;
  void allVisible(WidgetTester tester) {
    final screen =
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    for (final finder in [
      find.byKey(const ValueKey('practice-target')),
      find.byKey(const ValueKey('practice-hint')),
      find.byKey(const ValueKey('practice-feedback')),
      find.byKey(const ValueKey('touch-morse-key')),
      find.byKey(const ValueKey('practice-group')),
      find.byKey(const ValueKey('practice-correct')),
      find.text('Dot'),
      find.text('Dash'),
      find.byTooltip('Skip letter'),
      find.byTooltip('Finish letter'),
    ]) {
      final bounds = tester.getRect(finder);
      expect(
        screen.contains(bounds.topLeft),
        isTrue,
        reason: '$finder top visible',
      );
      expect(
        screen.contains(bounds.bottomRight),
        isTrue,
        reason: '$finder bottom visible',
      );
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    }
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('practice-workspace')),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  }

  Future<void> send(WidgetTester tester, String code) async {
    for (final signal in code.split('')) {
      await tester.tap(find.text(signal == '.' ? 'Dot' : 'Dash'));
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.tap(find.byTooltip('Finish letter'));
    await tester.pump();
  }

  Future<void> preview(WidgetTester tester, String name) async {
    if (!capture) return;
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('artifacts').create(recursive: true);
      await File('artifacts/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(568, 320),
    const Size(844, 390),
    const Size(800, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('Practice fits without scrolling during touch at $size', (
      tester,
    ) async {
      await openPractice(tester, size: size);
      allVisible(tester);
      final keyBounds = tester.getRect(
        find.byKey(const ValueKey('touch-morse-key')),
      );
      final gesture = await tester.startGesture(keyBounds.center);
      await tester.pump(const Duration(milliseconds: 350));
      allVisible(tester);
      expect(
        tester.getRect(find.byKey(const ValueKey('touch-morse-key'))),
        keyBounds,
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      if (size.width == 390) await preview(tester, 'practice-phone');
      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pumpAndSettle();
      allVisible(tester);
      if (size.width == 390) await preview(tester, 'practice-phone-dark');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('correct answers advance once; wrong answers stay for retry', (
    tester,
  ) async {
    await openPractice(tester);
    expect(target(tester), 'E');
    await send(tester, '-');
    expect(feedback(tester), contains('Try E again'));
    await tester.pump(const Duration(milliseconds: 1400));
    expect(target(tester), 'E');
    await tester.tap(find.byTooltip('Hide hint'));
    await tester.pump();
    await send(tester, '.');
    expect(feedback(tester), 'Correct! Next letter…');
    expect(target(tester), 'E');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('practice-correct'))).data,
      '1',
    );
    await preview(tester, 'practice-correct-feedback');
    await tester.pump(const Duration(milliseconds: 649));
    expect(target(tester), 'E');
    await tester.pump(const Duration(milliseconds: 1));
    final next = target(tester);
    expect(next, isNot('E'));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('practice-hint'))).data,
      '? ? ?',
    );
    await tester.pump(const Duration(seconds: 2));
    expect(target(tester), next);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('practice-correct'))).data,
      '1',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'pausing after a touch sends the answer and advances automatically',
    (tester) async {
      await openPractice(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('touch-morse-key'))),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(feedback(tester), 'Correct! Next letter…');
      expect(target(tester), 'E');
      await tester.pump(const Duration(milliseconds: 650));
      expect(target(tester), isNot('E'));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('practice-correct')))
            .data,
        '1',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('opening settings pauses advance until the dialog closes', (
    tester,
  ) async {
    await openPractice(tester);
    await send(tester, '.');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(target(tester), 'E');
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 650));
    expect(target(tester), isNot('E'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('leaving Practice cancels the pending advance', (tester) async {
    await openPractice(tester);
    await send(tester, '.');
    await tester.tap(find.text('Morse tree').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    expect(target(tester), 'E');
    expect(feedback(tester), 'Pause to send your letter');
    expect(tester.takeException(), isNull);
  });
  testWidgets('switching group cancels the previous scheduled advance', (
    tester,
  ) async {
    await openPractice(tester);
    await send(tester, '.');
    tester
        .widget<DropdownButton<String>>(
          find.byKey(const ValueKey('practice-group')),
        )
        .onChanged!('ET');
    await tester.pump();
    final next = target(tester);
    expect('ET', contains(next));
    await tester.pump(const Duration(seconds: 1));
    expect(target(tester), next);
    expect(tester.takeException(), isNull);
  });
  testWidgets('background pauses and resume restarts the feedback delay', (
    tester,
  ) async {
    await openPractice(tester);
    await send(tester, '.');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    expect(target(tester), 'E');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 649));
    expect(target(tester), 'E');
    await tester.pump(const Duration(milliseconds: 1));
    expect(target(tester), isNot('E'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('disposing a correct answer cancels its advance timer', (
    tester,
  ) async {
    await openPractice(tester);
    await send(tester, '.');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'hint preference survives skip, group changes and tab navigation',
    (tester) async {
      await openPractice(tester);
      await tester.tap(find.byTooltip('Hide hint'));
      await tester.pump();
      await tester.tap(find.byTooltip('Skip letter'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('practice-hint'))).data,
        '? ? ?',
      );
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('practice-group')),
          )
          .onChanged!('ET');
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('practice-hint'))).data,
        '? ? ?',
      );
      await tester.tap(find.text('Morse tree').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practice').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('practice-hint'))).data,
        '? ? ?',
      );
      await tester.tap(find.byTooltip('Show hint'));
      await tester.pump();
      await tester.tap(find.byTooltip('Skip letter'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('practice-hint'))).data,
        symbols(morse[target(tester)]!),
      );
      expect(find.byTooltip('Hide hint'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('hint preference is saved and restored across app restarts', (
    tester,
  ) async {
    const channel = MethodChannel('studio.dit/device');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Old saved preferences without hideHint must still show hints by default.
    String? stored = jsonEncode({'sound': false});
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'load') return stored;
      if (call.method == 'save') stored = call.arguments as String;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await openPractice(tester);
    expect(find.byTooltip('Hide hint'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide hint'));
    await tester.pumpAndSettle();
    expect(jsonDecode(stored!)['hideHint'], isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const DitApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('practice-hint'))).data,
      '? ? ?',
    );
    expect(find.byTooltip('Show hint'), findsOneWidget);
    await tester.tap(find.byTooltip('Show hint'));
    await tester.pumpAndSettle();
    expect(jsonDecode(stored!)['hideHint'], isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const DitApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('practice-hint'))).data,
      symbols(morse[target(tester)]!),
    );
    expect(find.byTooltip('Hide hint'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
