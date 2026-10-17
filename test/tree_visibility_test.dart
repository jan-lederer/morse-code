import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dit_morse/main.dart';
import 'package:dit_morse/morse.dart';

void main() {
  const capture = bool.fromEnvironment('CAPTURE_TREE_PREVIEWS');
  setUpAll(() async {
    if (!capture) return;
    final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
    for (final family in ['Roboto', 'Ahem', 'MaterialIcons']) {
      final path = family == 'MaterialIcons'
          ? '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
          : '$root/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf';
      final font = File(path);
      if (font.existsSync()) {
        final loader = FontLoader(family)
          ..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          );
        await loader.load();
      }
    }
  });

  void expectVisible(WidgetTester tester, bool numbers) {
    final viewport =
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    final bounds = tester.getRect(
      find.byKey(const ValueKey('whole-morse-tree')),
    );
    final key = tester.getRect(find.byKey(const ValueKey('touch-morse-key')));
    expect(viewport.contains(bounds.topLeft), isTrue);
    expect(viewport.contains(bounds.bottomRight), isTrue);
    expect(viewport.contains(key.topLeft), isTrue);
    expect(viewport.contains(key.bottomRight), isTrue);
    expect(bounds.overlaps(key), isFalse);
    for (final node in treeNodes(numbers)) {
      final rect = tester.getRect(
        find.byKey(ValueKey('tree-node-${node.code}')),
      );
      expect(
        bounds.contains(rect.topLeft),
        isTrue,
        reason: '${node.letter} left/top visible',
      );
      expect(
        bounds.contains(rect.bottomRight),
        isTrue,
        reason: '${node.letter} right/bottom visible',
      );
    }
    expect(tester.takeException(), isNull);
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(568, 320),
    const Size(844, 390),
    const Size(800, 1024),
  ]) {
    testWidgets(
      'whole tree and key stay visible during tap and hold at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const DitApp());
        await tester.pumpAndSettle();
        final originalBounds = tester.getRect(
          find.byKey(const ValueKey('whole-morse-tree')),
        );
        expectVisible(tester, false);
        final dot = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('touch-morse-key'))),
        );
        await tester.pump(const Duration(milliseconds: 60));
        expectVisible(tester, false);
        expect(
          (tester
                      .widget<AnimatedContainer>(
                        find.byKey(const ValueKey('tree-node-.')),
                      )
                      .decoration
                  as BoxDecoration)
              .color,
          coral,
        );
        await dot.up();
        await tester.pump(const Duration(milliseconds: 100));
        final dash = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('touch-morse-key'))),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expectVisible(tester, false);
        expect(
          tester.getRect(find.byKey(const ValueKey('whole-morse-tree'))),
          originalBounds,
        );
        expect(
          (tester
                      .widget<AnimatedContainer>(
                        find.byKey(const ValueKey('tree-node-.-')),
                      )
                      .decoration
                  as BoxDecoration)
              .color,
          coral,
        );
        if (capture && size.width == 390) {
          await tester.pump(const Duration(milliseconds: 150));
          final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('artifacts').create(recursive: true);
            await File('artifacts/tree-visible-while-holding.png')
                .writeAsBytes(png!.buffer.asUint8List());
          });
        }
        await dash.up();
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('compact-message')))
              .data,
          'A',
        );
        await tester.tap(find.byTooltip('Show numbers'));
        await tester.pumpAndSettle();
        expectVisible(tester, true);
        await tester.tap(find.byTooltip('Switch to dark mode'));
        await tester.pumpAndSettle();
        final held = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('touch-morse-key'))),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expectVisible(tester, true);
        await held.cancel();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('compact-message')))
              .data,
          'A',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
