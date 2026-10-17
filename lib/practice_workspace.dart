import 'package:flutter/material.dart';

import 'morse.dart';
import 'morse_key.dart';

/// Keeps the target, key, feedback, and progress in one bounded viewport.
class PracticeWorkspace extends StatelessWidget {
  final bool dark, pressed, holdDash, playing, hideHint;
  final String target, path, result, group;
  final int correct, attempts, learned;
  final Map<String, String> groups;
  final ValueChanged<String> onGroup;
  final VoidCallback onHint, onListen, onNext, onDot, onDash, onCommit;
  final PointerDownEventListener onDown;
  final PointerUpEventListener onUp;
  final PointerCancelEventListener onCancel;
  const PracticeWorkspace({
    super.key,
    required this.dark,
    required this.pressed,
    required this.holdDash,
    required this.playing,
    required this.hideHint,
    required this.target,
    required this.path,
    required this.result,
    required this.group,
    required this.correct,
    required this.attempts,
    required this.learned,
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
  });
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
  Widget panel(Widget child) => Container(
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
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      label('Practice', size: 18, weight: FontWeight.w600),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<String>(
                          key: const ValueKey('practice-group'),
                          value: group,
                          isExpanded: true,
                          dropdownColor: surface,
                          underline: const SizedBox(),
                          icon: Icon(Icons.expand_more, size: 18, color: muted),
                          items: groups.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: label(
                                    entry.value,
                                    size: 12,
                                    color: muted,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) onGroup(value);
                          },
                        ),
                      ),
                    ],
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
                            Expanded(flex: 5, child: controls()),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(flex: 3, child: challenge(false)),
                            const SizedBox(height: 10),
                            Expanded(flex: 2, child: controls()),
                          ],
                        ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      stat(
                        '$correct',
                        'Correct',
                        key: const ValueKey('practice-correct'),
                      ),
                      stat(
                        attempts == 0
                            ? '0%'
                            : '${(correct / attempts * 100).round()}%',
                        'Accuracy',
                      ),
                      stat('$learned', 'Practiced'),
                    ],
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
    hideHint ? '? ? ?' : symbols(morse[target]!),
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
        SizedBox(
          height: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: TextButton.icon(
                  onPressed: onListen,
                  icon: Icon(
                    playing
                        ? Icons.stop_circle_outlined
                        : Icons.headphones_outlined,
                    size: 16,
                    color: muted,
                  ),
                  label: label(
                    playing ? 'Stop' : 'Listen',
                    size: 11,
                    color: muted,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              IconButton(
                tooltip: hideHint ? 'Show hint' : 'Hide hint',
                onPressed: onHint,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  hideHint
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 24,
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: label(
                result.isEmpty
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
          ignoring: result == 'correct',
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
              onPressed: onCommit,
              style: IconButton.styleFrom(backgroundColor: surface),
              icon: Icon(Icons.check, size: 19, color: ink),
            ),
            IconButton(
              tooltip: 'Skip letter',
              onPressed: onNext,
              icon: Icon(Icons.skip_next_outlined, size: 23, color: muted),
            ),
          ],
        ),
      ),
    ],
  );
  Widget manualButton(String text, IconData icon, VoidCallback onTap) =>
      FilledButton.icon(
        onPressed: result == 'correct' ? null : onTap,
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
  Widget stat(String value, String title, {Key? key}) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        label(value, key: key, size: 17, weight: FontWeight.w600),
        const SizedBox(width: 6),
        Flexible(child: label(title, size: 9, color: muted)),
      ],
    ),
  );
}
