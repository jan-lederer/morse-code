import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dit_morse/main.dart';
import 'package:dit_morse/template_icons.dart';
import 'package:dit_morse/morse.dart';

void main() {
  testWidgets('app brand displays morse instead of dit', (tester) async {
    await tester.pumpWidget(const DitApp());
    await tester.pumpAndSettle();
    expect(find.text('morse.'), findsOneWidget);
    expect(find.text('dit.'), findsNothing);
  });
  testWidgets('settings language changes app UI but leaves tab names alone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => _loadSdkFonts(tester));
    await tester.pumpWidget(const DitApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('language-selector')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DE').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after selecting German');
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);
    expect(find.text('Tune the look and feel of your app.'), findsOneWidget);
    await tester.tap(find.byIcon(TemplateIcons.close));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after closing settings');
    expect(find.text('Learn'), findsOneWidget);
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after opening Learn');
    expect(find.text('Dein Fortschritt'), findsOneWidget);
    expect(find.text('Learn'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    'phone layouts, settings theme choice and navigation stay usable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => _loadSdkFonts(tester));
      final screenshotKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: screenshotKey, child: const DitApp()),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('whole-morse-tree')), findsOneWidget);
      final settingsButton = find.ancestor(
        of: find.byTooltip('Open settings'),
        matching: find.byType(IconButton),
      );
      expect(tester.getRect(settingsButton).right, closeTo(370, 1));

      Future<void> captureDark(String filename) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(screenshotKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('screenshots/$filename');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          expect(await output.length(), greaterThan(10000));
        });
      }

      expect(find.byTooltip('Switch to dark theme'), findsNothing);
      await tester.tap(find.byTooltip('Open settings'));
      await tester.pumpAndSettle();
      final colorModeSelector = find.byKey(
        const ValueKey('color-mode-selector'),
      );
      expect(
        tester.widget<SegmentedButton<ThemeMode>>(colorModeSelector).selected,
        {ThemeMode.system},
      );
      await tester.tap(find.byIcon(TemplateIcons.darkAppearance));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SegmentedButton<ThemeMode>>(colorModeSelector).selected,
        {ThemeMode.dark},
      );
      await tester.tap(find.byIcon(TemplateIcons.close));
      await tester.pumpAndSettle();
      await captureDark('morse-tree-dark.png');
      await tester.tap(find.byTooltip('Open settings'));
      await tester.pumpAndSettle();
      expect(find.text('Tune the look and feel of your app.'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);
      expect(find.byTooltip('Open-source licenses'), findsOneWidget);
      expect(find.byKey(const ValueKey('privacy-policy-link')), findsOneWidget);
      expect(find.text('Open-source licenses'), findsNothing);
      expect(
        find.text('Little adjustments for a more comfortable practice.'),
        findsNothing,
      );
      await captureDark('settings-dark.png');
      await tester.tap(find.byIcon(TemplateIcons.close));
      await tester.pumpAndSettle();
      for (final label in ['Learn', 'Practice', 'Alphabet', 'Morse tree']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        if (label == 'Learn') {
          expect(find.text('MORSE'), findsOneWidget);
          expect(find.text('FUTURE-READY LEARNING KIT'), findsNothing);
          await captureDark('learn-dark.png');
        }
        if (label == 'Practice') await captureDark('practice-dark.png');
        expect(
          tester.takeException(),
          isNull,
          reason: '$label should fit phone',
        );
      }
      await tester.tap(find.text('Practice').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('practice-direction-listen')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('practice-answer-style')),
          matching: find.text('4'),
        ),
      );
      await tester.pumpAndSettle();
      await captureDark('listening-choices-dark.png');
      expect(
        tester.takeException(),
        isNull,
        reason: 'listening choices fit phone',
      );
    },
  );
  testWidgets('walkthrough spotlights tabs and page features in sequence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DitApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('1 / 9'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('1 / 9')).style!.decoration,
      TextDecoration.none,
    );
    expect(find.text('Learn tab'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Learn tab')).style!.decoration,
      TextDecoration.none,
    );
    expect(find.text('Learn'), findsWidgets);
    expect(
      tester.getTopLeft(find.byTooltip('Skip walkthrough')).dy,
      greaterThanOrEqualTo(32),
    );
    final spotlightFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.key is ValueKey<Rect>,
    );
    final initialSpotlightKey = tester.widget<CustomPaint>(spotlightFinder).key;
    await tester.tap(find.byTooltip('Next step'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('walkthrough-tab-tap-animation')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('2 / 9'), findsOneWidget);
    final movingSpotlightKey = tester.widget<CustomPaint>(spotlightFinder).key;
    expect(movingSpotlightKey, isNot(initialSpotlightKey));
    await tester.pumpAndSettle();
    expect(find.text('Proficiency bars'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('learn-character-mastery')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Morse tree tab'), findsOneWidget);
    await tester.tap(find.byTooltip('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Explore the tree'), findsOneWidget);
    expect(find.byKey(const ValueKey('whole-morse-tree')), findsOneWidget);
    await tester.tap(find.byTooltip('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Practice tab'), findsOneWidget);
    await tester.tap(find.byTooltip('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Practice settings'), findsOneWidget);
    expect(find.byTooltip('Sending mode'), findsOneWidget);
    expect(find.byKey(const ValueKey('practice-answer-style')), findsOneWidget);
    expect(find.byKey(const ValueKey('practice-group')), findsOneWidget);
    await tester.tap(find.byTooltip('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Practice a signal'), findsOneWidget);
    expect(find.byKey(const ValueKey('practice-target')), findsOneWidget);
    await tester.tap(find.byTooltip('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Alphabet tab'), findsOneWidget);
    await tester.tap(find.byTooltip('Next step'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('walkthrough-tab-tap-animation')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.text('Look up a character'), findsOneWidget);
    expect(find.byKey(const ValueKey('alphabet-entry-A')), findsOneWidget);
    await tester.tap(find.byTooltip('Previous step'));
    await tester.pumpAndSettle();
    expect(find.text('Alphabet tab'), findsOneWidget);
    await tester.tap(find.byTooltip('Skip walkthrough'));
    await tester.pumpAndSettle();
    expect(find.text('Look up a character'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _loadSdkFonts(WidgetTester tester) async {
  final packages = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final entries = packages['packages'] as List<dynamic>;
  final flutterPackage = entries.firstWhere((p) => p['name'] == 'flutter');
  final sdk = Directory.fromUri(Uri.parse(flutterPackage['rootUri'] as String))
      .parent
      .parent
      .path;
  final root = '$sdk/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          await File('$root/Roboto-Regular.ttf').readAsBytes(),
        ),
      ),
    );
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          await File('$root/MaterialIcons-Regular.otf').readAsBytes(),
        ),
      ),
    );
  await icons.load();
}
