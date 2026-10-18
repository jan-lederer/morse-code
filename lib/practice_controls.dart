import 'package:flutter/material.dart';

enum PracticeMode {
  send('Send signals'),
  type('Type an answer'),
  choices('4 choices'),
  sendChoices('Send · 4 choices');

  const PracticeMode(this.label);
  final String label;
}

class MasteryDistributionBar extends StatelessWidget {
  const MasteryDistributionBar({
    super.key,
    required this.counts,
    required this.dark,
    this.showCounts = true,
    this.height = 16,
  });

  /// Counts are ordered red, yellow, green; the visual bar is green first.
  final List<int> counts;
  final bool dark;
  final bool showCounts;
  final double height;

  static const colors = [
    Color(0xFFD97968),
    Color(0xFFD6A84F),
    Color(0xFF648D78),
  ];

  @override
  Widget build(BuildContext context) {
    final order = [2, 1, 0];
    return Semantics(
      label:
          'Current practice set proficiency: green ${counts[2]}, yellow ${counts[1]}, red ${counts[0]}',
      child: SizedBox(
        key: const ValueKey('mastery-distribution'),
        width: double.infinity,
        height: height,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: showCounts ? 12 : height,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF353D3B)
                      : const Color(0xFFE4E7DC),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    for (final level in order)
                      if (counts[level] > 0)
                        Expanded(
                          flex: counts[level],
                          child: ColoredBox(
                            color: colors[level],
                            child: const SizedBox.expand(),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            if (showCounts) ...[
              const SizedBox(width: 8),
              Text(
                'G ${counts[2]}  Y ${counts[1]}  R ${counts[0]}',
                key: const ValueKey('mastery-distribution-counts'),
                style: TextStyle(
                  fontSize: 9,
                  color: dark
                      ? const Color(0xFFB8C0BC)
                      : const Color(0xFF747E77),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PracticeStats extends StatelessWidget {
  const PracticeStats({
    super.key,
    required this.correct,
    required this.attempts,
    this.examQuestion,
    this.examLives,
    this.examStatus = '',
  });
  final int correct, attempts;
  final int? examQuestion, examLives;
  final String examStatus;

  Widget _stat(String value, String title, {Key? key}) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          key: key,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: examQuestion == null
        ? Row(
            children: [
              _stat(
                '$correct',
                'Correct',
                key: const ValueKey('practice-correct'),
              ),
              _stat(
                attempts == 0 ? '0%' : '${(correct / attempts * 100).round()}%',
                'Accuracy',
              ),
              _stat('$attempts', 'Answers'),
            ],
          )
        : Row(
            children: [
              _stat(
                '$examQuestion / 20',
                'Question',
                key: const ValueKey('exam-question'),
              ),
              _stat('$examLives', 'Lives'),
              Expanded(
                child: Text(
                  examStatus == 'passed'
                      ? 'PASSED'
                      : examStatus == 'failed'
                      ? 'FAILED'
                      : 'Exam',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: examStatus == 'failed'
                        ? const Color(0xFFE77860)
                        : examStatus == 'passed'
                        ? const Color(0xFF648D78)
                        : null,
                  ),
                ),
              ),
            ],
          ),
  );
}

class PracticeHeader extends StatelessWidget {
  const PracticeHeader({
    super.key,
    required this.mode,
    required this.group,
    required this.groups,
    required this.onMode,
    required this.onGroup,
    this.onNewSession,
    this.exam = false,
  });
  final PracticeMode mode;
  final String group;
  final Map<String, String> groups;
  final ValueChanged<PracticeMode> onMode;
  final ValueChanged<String> onGroup;
  final VoidCallback? onNewSession;
  final bool exam;

  bool get _sending =>
      mode == PracticeMode.send || mode == PracticeMode.sendChoices;
  bool get _choices =>
      mode == PracticeMode.choices || mode == PracticeMode.sendChoices;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: Row(
      children: [
        for (final sending in [false, true])
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              key: ValueKey(
                'practice-direction-${sending ? 'send' : 'listen'}',
              ),
              tooltip: sending ? 'Sending mode' : 'Listening mode',
              isSelected: _sending == sending,
              onPressed: exam
                  ? null
                  : () => onMode(
                      sending
                          ? (_choices
                                ? PracticeMode.sendChoices
                                : PracticeMode.send)
                          : (_choices
                                ? PracticeMode.choices
                                : PracticeMode.type),
                    ),
              style: IconButton.styleFrom(
                backgroundColor: _sending == sending
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Colors.transparent,
              ),
              icon: Icon(
                sending ? Icons.touch_app_outlined : Icons.headphones_outlined,
                size: 19,
              ),
            ),
          ),
        const SizedBox(width: 8),
        SegmentedButton<bool>(
          key: const ValueKey('practice-answer-style'),
          segments: const [
            ButtonSegment(value: false, label: Text('Type')),
            ButtonSegment(value: true, label: Text('4')),
          ],
          selected: {_choices},
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            minimumSize: const Size(30, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onSelectionChanged: exam
              ? null
              : (value) => onMode(
                  _sending
                      ? (value.first
                            ? PracticeMode.sendChoices
                            : PracticeMode.send)
                      : (value.first
                            ? PracticeMode.choices
                            : PracticeMode.type),
                ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Tooltip(
            message: 'Practice set: ${groups[group] ?? group}',
            child: DropdownButton<String>(
              key: const ValueKey('practice-group'),
              value: group,
              isExpanded: true,
              menuWidth: MediaQuery.sizeOf(context).width * .85,
              menuMaxHeight: MediaQuery.sizeOf(context).height * .65,
              underline: const SizedBox(),
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              selectedItemBuilder: (context) => groups.entries
                  .map(
                    (entry) => Center(
                      child: Icon(
                        _groupIcon(entry.value),
                        key: ValueKey('practice-group-selected-${entry.key}'),
                        size: 20,
                      ),
                    ),
                  )
                  .toList(),
              items: groups.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Row(
                        children: [
                          Icon(
                            _groupIcon(e.value),
                            key: ValueKey('practice-group-option-${e.key}'),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              e.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onGroup(value);
              },
            ),
          ),
        ),
        if (onNewSession != null)
          IconButton(
            tooltip: exam ? 'Start new exam' : 'New practice',
            onPressed: onNewSession,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(Icons.refresh, size: 19),
          ),
      ],
    ),
  );

  IconData _groupIcon(String label) => switch (label) {
    _ when label.startsWith('Alphabet') => Icons.sort_by_alpha,
    _ when label.startsWith('Numbers') => Icons.numbers,
    _ when label.startsWith('Words') => Icons.short_text,
    _ when label.startsWith('Sentences') => Icons.subject,
    _ when label.startsWith('All symbols') => Icons.grid_view_outlined,
    _ when label.startsWith('Exam') => Icons.assignment_outlined,
    _ => Icons.list_alt_outlined,
  };
}

class PracticeSignalActions extends StatelessWidget {
  const PracticeSignalActions({
    super.key,
    required this.playing,
    required this.hideHint,
    required this.onListen,
    required this.onHint,
  });
  final bool playing, hideHint;
  final VoidCallback onListen, onHint;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: TextButton.icon(
            onPressed: onListen,
            icon: Icon(
              playing ? Icons.stop_circle_outlined : Icons.headphones_outlined,
              size: 16,
            ),
            label: Text(
              playing ? 'Stop' : 'Listen',
              style: const TextStyle(fontSize: 11),
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
          ),
        ),
      ],
    ),
  );
}
