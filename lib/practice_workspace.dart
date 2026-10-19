import 'package:flutter/material.dart';

import 'morse.dart';
import 'morse_key.dart';
import 'practice_controls.dart';

/// Keeps the target, key, feedback, and progress in one bounded viewport.
class PracticeWorkspace extends StatelessWidget {
  final GlobalKey? walkthroughKey;
  final GlobalKey? walkthroughControlsKey;
  final bool dark, pressed, holdDash, playing, hideHint;
  final bool fourChoices;
  final bool examMode;
  final int examQuestion, examLives;
  final String examStatus;
  final String target, path, result, group, hintCharacter;
  final int correct, attempts;
  final List<int> masteryCounts;
  final Map<String, String> groups;
  final ValueChanged<String> onGroup;
  final ValueChanged<PracticeMode> onMode;
  final VoidCallback? onNewSession;
  final VoidCallback onHint, onListen, onNext, onDot, onDash, onCommit;
  final List<String> choices;
  final ValueChanged<String> onChoice;
  final PointerDownEventListener onDown;
  final PointerUpEventListener onUp;
  final PointerCancelEventListener onCancel;
  const PracticeWorkspace({
    super.key,
    this.walkthroughKey,
    this.walkthroughControlsKey,
    required this.dark,
    required this.pressed,
    required this.holdDash,
    required this.playing,
    required this.hideHint,
    this.fourChoices = false,
    this.examMode = false,
    this.examQuestion = 0,
    this.examLives = 3,
    this.examStatus = '',
    required this.target,
    this.hintCharacter = '',
    required this.path,
    required this.result,
    required this.group,
    required this.correct,
    required this.attempts,
    this.masteryCounts = const [36, 0, 0],
    required this.groups,
    required this.onGroup,
    required this.onHint,
    required this.onListen,
    required this.onNext,
    required this.onDown,
    required this.onUp,
    required this.onCancel,
    required this.onDot,
    required this.onDash,
    required this.onCommit,
    this.choices = const [],
    this.onChoice = _ignoreChoice,
    required this.onMode,
    this.onNewSession,
  });
  static void _ignoreChoice(String _) {}
  static const accent = Color(0xFFE77860), green = Color(0xFF648D78);
  Color get ink => dark ? const Color(0xFFF0F1EC) : const Color(0xFF26302F);
  Color get muted => dark ? const Color(0xFF9AA4A0) : const Color(0xFF747E77);
  Color get line => dark ? const Color(0xFF353D3B) : const Color(0xFFE4E7DC);
  Color get surface => dark ? const Color(0xFF202627) : Colors.white;
  Text label(
    String text, {
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w400,
    Key? key,
  }) => Text(
    text,
    key: key,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: size, color: color ?? ink, fontWeight: weight),
  );
  Widget panel(Widget child, {Key? key}) => Container(
    key: key,
    decoration: BoxDecoration(
      color: surface,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(16),
    ),
    padding: const EdgeInsets.all(10),
    child: child,
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, c) {
            final horizontal = c.maxWidth > c.maxHeight * 1.05;
            return Column(
              key: const ValueKey('practice-workspace'),
              children: [
                KeyedSubtree(
                  key: walkthroughControlsKey,
                  child: PracticeHeader(
                    mode: fourChoices
                        ? PracticeMode.sendChoices
                        : PracticeMode.send,
                    group: group,
                    groups: groups,
                    onMode: onMode,
                    onGroup: onGroup,
                    onNewSession: onNewSession,
                    exam: examMode,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: horizontal
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 4, child: challenge(true)),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: fourChoices ? _choices() : controls(),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(flex: 3, child: challenge(false)),
                            const SizedBox(height: 10),
                            Expanded(
                              flex: 2,
                              child: fourChoices ? _choices() : controls(),
                            ),
                          ],
                        ),
                ),
                MasteryDistributionBar(
                  counts: masteryCounts,
                  dark: dark,
                  showCounts: false,
                  height: 8,
                ),
                SizedBox(
                  key: const ValueKey('practice-stats'),
                  height: 34,
                  child: PracticeStats(
                    correct: correct,
                    attempts: attempts,
                    examQuestion: examMode ? examQuestion : null,
                    examLives: examLives,
                    examStatus: examStatus,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget targetLetter() => FittedBox(
    fit: BoxFit.contain,
    child: label(
      target,
      key: const ValueKey('practice-target'),
      size: 100,
      weight: FontWeight.w500,
    ),
  );
  Widget hint() => label(
    hideHint
        ? '? ? ?'
        : symbols(
            morse[hintCharacter.isNotEmpty
                ? hintCharacter
                : target.isEmpty
                ? 'E'
                : target[0]]!,
          ),
    key: const ValueKey('practice-hint'),
    size: 24,
    color: accent,
    weight: FontWeight.w500,
  );
  Widget challenge(bool horizontal) => panel(
    Column(
      children: [
        if (!horizontal) ...[
          label(
            'SEND THIS LETTER',
            size: 9,
            color: muted,
            weight: FontWeight.w600,
          ),
          const SizedBox(height: 4),
        ],
        Expanded(
          child: horizontal
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: targetLetter(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Center(child: hint())),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: targetLetter(),
                ),
        ),
        if (!horizontal) SizedBox(height: 30, child: Center(child: hint())),
        PracticeSignalActions(
          playing: playing,
          hideHint: hideHint,
          onListen: onListen,
          onHint: onHint,
        ),
        if (examStatus.isNotEmpty)
          SizedBox(
            height: 32,
            child: Center(
              child: TextButton.icon(
                key: const ValueKey('terminal-new-exam'),
                onPressed: onNewSession,
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('New exam'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 24,
            child: Center(
              child: Semantics(
                liveRegion: true,
                child: label(
                  examStatus == 'failed'
                      ? 'Exam failed · three mistakes'
                      : examStatus == 'passed'
                      ? 'Exam passed!'
                      : result == 'progress'
                      ? 'Good. Send the next letter.'
                      : result.isEmpty
                      ? 'Pause to send your letter'
                      : result == 'correct'
                      ? 'Correct! Next letter…'
                      : 'You sent $result. Try $target again.',
                  key: const ValueKey('practice-feedback'),
                  size: 11,
                  color: result == 'correct'
                      ? green
                      : result.isEmpty
                      ? muted
                      : accent,
                  weight: result.isEmpty ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    ),
    key: walkthroughKey,
  );

  Widget controls() => Column(
    children: [
      SizedBox(
        height: 26,
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: label(
                path.isEmpty
                    ? '—'
                    : decode(path).isEmpty
                    ? '?'
                    : decode(path),
                size: 22,
                color: accent,
                weight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: label(
                path.isEmpty ? 'Your next signal' : symbols(path),
                size: path.isEmpty ? 11 : 19,
                color: path.isEmpty ? muted : ink,
              ),
            ),
            if (result == 'correct')
              Icon(Icons.check_circle_outline, size: 18, color: green),
          ],
        ),
      ),
      const SizedBox(height: 5),
      Expanded(
        child: IgnorePointer(
          ignoring: _locked,
          child: MorseKey(
            dark: dark,
            pressed: pressed,
            holdDash: holdDash,
            onDown: onDown,
            onUp: onUp,
            onCancel: onCancel,
          ),
        ),
      ),
      const SizedBox(height: 7),
      SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(child: manualButton('Dot', Icons.circle, onDot)),
            const SizedBox(width: 6),
            Expanded(child: manualButton('Dash', Icons.remove, onDash)),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Finish letter',
              onPressed: _locked ? null : onCommit,
              style: IconButton.styleFrom(backgroundColor: surface),
              icon: Icon(Icons.check, size: 19, color: ink),
            ),
            IconButton(
              tooltip: 'Skip letter',
              onPressed: examMode ? null : onNext,
              icon: Icon(Icons.skip_next_outlined, size: 23, color: muted),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _choices() => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 8.0;
      final tileWidth = (constraints.maxWidth - gap) / 2;
      final tileHeight = (constraints.maxHeight - gap) / 2;
      return GridView.count(
        crossAxisCount: 2,
        childAspectRatio: tileWidth / tileHeight,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        physics: const NeverScrollableScrollPhysics(),
        children: choices
            .map(
              (code) => OutlinedButton(
                key: ValueKey('send-choice-$code'),
                onPressed: _locked ? null : () => onChoice(code),
                style: OutlinedButton.styleFrom(
                  backgroundColor: dark
                      ? const Color(0xFF322B28)
                      : const Color(0xFFFFF1EB),
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: .5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  symbols(code),
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            )
            .toList(),
      );
    },
  );
  Widget manualButton(String text, IconData icon, VoidCallback onTap) =>
      FilledButton.icon(
        onPressed: _locked ? null : onTap,
        icon: Icon(icon, size: 12),
        label: Text(text),
        style: FilledButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  bool get _locked =>
      examStatus.isNotEmpty ||
      result == 'correct' ||
      result == 'exam-passed' ||
      result == 'exam-failed';
}
