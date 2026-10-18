import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dit_morse/main.dart';
import 'package:dit_morse/practice_controls.dart';
import 'package:dit_morse/progress_history.dart';

void main() {
  test('mastery advances red to yellow to green and mistakes regress', () {
    expect(masteryLevel([]), 0);
    expect(masteryLevel([true]), 0);
    expect(masteryLevel([true, true]), 1);
    expect(masteryLevel([true, true, true, true, true]), 2);
    expect(masteryLevel([true, true, true, true, true, false]), 1);
    expect(masteryLevel([true, true, true, true, true, false, false]), 0);
  });

  test('phrase mastery moves one color per answer', () {
    expect(masteryLevel([true], singleStep: true), 1);
    expect(masteryLevel([true, true], singleStep: true), 2);
    expect(masteryLevel([true, true, false], singleStep: true), 1);
    expect(masteryLevel([true, true, false, false], singleStep: true), 0);
    expect(masteryLevel([false], singleStep: true), 0);
  });

  test('phrase mastery persists alongside existing character history', () {
    final history = ProgressHistory(
      records: [],
      masteryRecords: [
        MasteryRecord(
          id: 'phrase-1',
          at: DateTime.utc(2026),
          mode: PracticeMode.type,
          item: 'MORSE',
          kind: 'word',
          correct: true,
        ),
      ],
    );
    final restored = ProgressHistory.fromSaved({'progress': history.toJson()});
    expect(restored.masteryRecords.single.item, 'MORSE');
    expect(restored.masteryRecords.single.mode, PracticeMode.type);
  });

  testWidgets('Learn shows combined mastery bars', (tester) async {
    await tester.pumpWidget(const DitApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn').last);
    await tester.pumpAndSettle();
    expect(find.text('Your current level'), findsOneWidget);
    expect(find.text('Letters & numbers · all practice modes'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('learn-character-mastery')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learn-character-mastery')),
        matching: find.byType(ColoredBox),
      ),
      findsAtLeastNWidgets(1),
    );
    expect(find.textContaining('G 0  Y 0  R 36'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mastery bars begin green, then yellow, then red', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: MasteryDistributionBar(counts: [1, 2, 3], dark: false),
          ),
        ),
      ),
    );
    final colors = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byKey(const ValueKey('mastery-distribution')),
            matching: find.byType(ColoredBox),
          ),
        )
        .map((box) => box.color)
        .toList();
    expect(colors, [
      const Color(0xFF648D78),
      const Color(0xFFD6A84F),
      const Color(0xFFD97968),
    ]);
  });
}
