import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dit_morse/main.dart';
import 'package:dit_morse/morse.dart';

void main() {
  testWidgets('app brand displays morse instead of dit', (tester) async {
    await tester.pumpWidget(const DitApp());
    await tester.pumpAndSettle();
    expect(find.text('morse.'), findsOneWidget);
    expect(find.text('dit.'), findsNothing);
  });
  test('all standard characters have unique signals and round-trip', () {
    expect(morse.length, 36);
    expect(morse.values.toSet().length, 36);
    for (final entry in morse.entries) {
      expect(decode(entry.value), entry.key);
    }
    expect(encode('SOS 123'), '... --- ... / .---- ..--- ...--');
    expect(classifyPress(229, 230), '.');
    expect(classifyPress(230, 230), '-');
    expect(validPrefix('......'), false);
  });
  test(
    'tree includes every letter and optional numbers with their parents',
    () {
      expect(treeNodes(false).where((n) => n.letter.isNotEmpty).length, 26);
      final nodes = treeNodes(true);
      expect(nodes.where((n) => n.letter.isNotEmpty).length, 36);
      for (final node in nodes.where((n) => n.code.isNotEmpty)) {
        expect(
          nodes.any(
            (n) => n.code == node.code.substring(0, node.code.length - 1),
          ),
          true,
        );
      }
    },
  );
  testWidgets('touch input traces A, commits it, and supports editing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DitApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dot').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Dash').first);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.text('1 characters'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete last signal or character'));
    await tester.pumpAndSettle();
    expect(find.text('0 characters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'phone layouts, dark theme, navigation and settings stay usable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const DitApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('whole-morse-tree')), findsOneWidget);
      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Your rhythm, your rules.'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      for (final label in ['Learn', 'Practice', 'Alphabet', 'Morse tree']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$label should fit phone',
        );
      }
    },
  );
}
