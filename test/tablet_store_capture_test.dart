import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dit_morse/main.dart';

void main() {
  Future<void> captureScreens(
    WidgetTester tester, {
    required String device,
    required Size physicalSize,
    required double pixelRatio,
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const rootKey = ValueKey('tablet-capture-root');
    await tester.pumpWidget(
      const RepaintBoundary(key: rootKey, child: DitApp()),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pump(const Duration(milliseconds: 500));

    Future<void> save(String page) async {
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: '$device $page layout');
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(rootKey),
      );
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final target = File('build/deliverables/tablets/$device-$page.png');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      image.dispose();
    }

    await save('morse-tree');
    await tester.tap(find.text('Learn').first);
    await tester.pump(const Duration(milliseconds: 500));
    await save('learn');
    await tester.tap(find.text('Practice').first);
    await tester.pump(const Duration(milliseconds: 500));
    await save('practice');
    await tester.tap(find.byKey(const ValueKey('practice-direction-listen')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('practice-answer-style')),
        matching: find.text('4'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await save('listening-choices');
  }

  testWidgets('capture Google Play 7-inch tablet screenshots', (tester) async {
    await captureScreens(
      tester,
      device: 'tablet-7-inch',
      physicalSize: const Size(1920, 1080),
      pixelRatio: 2,
    );
  });

  testWidgets('capture Google Play 10-inch tablet screenshots', (tester) async {
    await captureScreens(
      tester,
      device: 'tablet-10-inch',
      physicalSize: const Size(2560, 1440),
      pixelRatio: 2,
    );
  });
}
