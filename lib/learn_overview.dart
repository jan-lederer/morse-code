import 'package:flutter/material.dart';

import 'morse.dart';
import 'practice_controls.dart';
import 'progress_history.dart';
import 'practice_content.dart';
import 'app_palette.dart';
import 'app_strings.dart';

class LearnOverview extends StatefulWidget {
  const LearnOverview({
    super.key,
    required this.history,
    required this.examsPassed,
    required this.lessons,
    required this.onPractice,
    required this.dark,
    this.walkthroughMasteryKey,
  });
  final ProgressHistory history;
  final int examsPassed;
  final List<(String, String, String)> lessons;
  final void Function(PracticeMode mode, String characters) onPractice;
  final bool dark;
  final GlobalKey? walkthroughMasteryKey;
  @override
  State<LearnOverview> createState() => _LearnOverviewState();
}

class _LearnOverviewState extends State<LearnOverview> {
  ProgressPeriod _period = ProgressPeriod.all;
  PracticeMode? _mode;
  String? _characters;
  static const green = Color(0xFF648D78);
  Color get accent => morseAccentFor(widget.dark);
  Color get ink =>
      widget.dark ? const Color(0xFFF1F5FA) : const Color(0xFF172235);
  Color get muted =>
      widget.dark ? const Color(0xFFB6C3D4) : const Color(0xFF56657B);
  Color get line =>
      widget.dark ? const Color(0xFF35465C) : const Color(0xFFDDE5EF);

  int _level(String item, {String? kind}) {
    final outcomes = kind == null
        ? widget.history.records
              .where((record) => record.letter == item)
              .map((record) => (record.at, record.correct))
              .toList()
        : widget.history.masteryRecords
              .where((record) => record.kind == kind && record.item == item)
              .map((record) => (record.at, record.correct))
              .toList();
    outcomes.sort((a, b) => a.$1.compareTo(b.$1));
    final level = masteryLevel(
      outcomes.map((record) => record.$2),
      singleStep: kind != null,
    );
    if (kind == null &&
        outcomes.isEmpty &&
        widget.history.earlierLetters.contains(item)) {
      return 1;
    }
    return level;
  }

  Widget _masteryBar(
    List<String> items, {
    String? kind,
    required String keyName,
  }) {
    final counts = List<int>.generate(
      3,
      (level) =>
          items.where((item) => _level(item, kind: kind) == level).length,
    );
    return MasteryDistributionBar(
      key: ValueKey(keyName),
      counts: counts,
      dark: widget.dark,
    );
  }

  Widget card(Widget child) => SizedBox(
    width: double.infinity,
    child: Material(
      color: widget.dark ? const Color(0xFF131D2D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: line),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
  Widget progress(int count, int total) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(
      value: count / total,
      minHeight: 5,
      color: green,
      backgroundColor: line,
    ),
  );
  Widget metric(String label, String value, {Key? key}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        key: key,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: ink),
      ),
      Text(tr(label), style: TextStyle(fontSize: 11, color: muted)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final overall = widget.history.summary();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Your progress'),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('An overview of your learning, across every mode.'),
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 18),
        Padding(
          key: widget.walkthroughMasteryKey,
          padding: EdgeInsets.zero,
          child: card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Your current level'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr(
                    'Mistakes move an item back. Stronger items appear less often.',
                  ),
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 14),
                Text(
                  tr('Letters & numbers · all practice modes'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                _masteryBar(
                  morse.keys.toList(),
                  keyName: 'learn-character-mastery',
                ),
                const SizedBox(height: 16),
                Text(
                  tr('Words'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 7),
                _masteryBar(
                  practiceWords,
                  kind: 'word',
                  keyName: 'learn-word-mastery',
                ),
                const SizedBox(height: 14),
                Text(
                  tr('Sentences'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 7),
                _masteryBar(
                  practiceSentences,
                  kind: 'sentence',
                  keyName: 'learn-sentence-mastery',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('Overall · all time'),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${overall.letters.length} / 36',
                    key: const ValueKey('learn-overall-progress'),
                    style: const TextStyle(color: green),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              progress(overall.letters.length, 36),
              const SizedBox(height: 6),
              Text(
                tr('Characters answered correctly'),
                style: TextStyle(fontSize: 11, color: muted),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: metric(
                      tr('Score · correct / answers'),
                      '${overall.correct} / ${overall.attempts}',
                      key: const ValueKey('learn-overall-score'),
                    ),
                  ),
                  Expanded(
                    child: metric(
                      tr('Accuracy'),
                      overall.accuracy == null ? '—' : '${overall.accuracy}%',
                      key: const ValueKey('learn-overall-accuracy'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              metric(
                tr('Exams passed'),
                '${widget.examsPassed}',
                key: const ValueKey('learn-exams-passed'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          tr('By practice mode'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        for (final mode in [PracticeMode.send, PracticeMode.type]) ...[
          _modeCard(mode),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        card(
          ExpansionTile(
            key: const PageStorageKey('learn-metrics'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            title: Text(
              tr('More metrics'),
              style: const TextStyle(fontSize: 15),
            ),
            subtitle: Text(
              tr('Dates, modes, chapters & character details'),
              style: TextStyle(fontSize: 11, color: muted),
            ),
            children: [_metrics()],
          ),
        ),
        const SizedBox(height: 12),
        card(
          ExpansionTile(
            key: const PageStorageKey('learn-chapters'),
            tilePadding: EdgeInsets.zero,
            title: Text(tr('Chapters'), style: const TextStyle(fontSize: 15)),
            subtitle: Text(
              tr('Two focused steps, at your own pace'),
              style: TextStyle(fontSize: 11, color: muted),
            ),
            children: [
              for (final lesson in widget.lessons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    tr(lesson.$1),
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: progress(
                      lesson.$2
                          .split('')
                          .where(overall.letters.contains)
                          .length,
                      lesson.$2.length,
                    ),
                  ),
                  trailing: Text(
                    '${lesson.$2.split('').where(overall.letters.contains).length} / ${lesson.$2.length}',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  onTap: () => widget.onPractice(PracticeMode.send, lesson.$2),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeCard(PracticeMode mode) {
    final sending = mode == PracticeMode.send;
    final relatedModes = sending
        ? [PracticeMode.send, PracticeMode.sendChoices]
        : [PracticeMode.type, PracticeMode.choices];
    final summary = ProgressSummary(
      widget.history.records
          .where((record) => relatedModes.contains(record.mode))
          .toList(),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onPractice(mode, alphabet),
        child: card(
          Row(
            children: [
              Icon(
                sending ? Icons.touch_app_outlined : Icons.hearing_outlined,
                size: 21,
                color: accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr(sending ? 'Sending' : 'Listening'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${summary.letters.length} / 36',
                          key: ValueKey('learn-mode-${mode.name}-progress'),
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                    Text(
                      tr(sending ? 'Signals or choices' : 'Typed or choices'),
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                    const SizedBox(height: 7),
                    progress(summary.letters.length, 36),
                    const SizedBox(height: 5),
                    Text(
                      tr('${summary.correct} / ${summary.attempts} correct'),
                      key: ValueKey('learn-mode-${mode.name}-score'),
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metrics() {
    final summary = widget.history.summary(
      period: _period,
      mode: _mode,
      characters: _characters,
    );
    final characters = _characters ?? morse.keys.join();
    final groups = <String?, String>{
      null: 'All characters',
      alphabet: 'Letters',
      '0123456789': 'Numbers',
      for (final lesson in widget.lessons) lesson.$2: lesson.$1,
    };
    final rows =
        characters
            .split('')
            .where((letter) => summary.records.any((r) => r.letter == letter))
            .map((letter) {
              final attempts = summary.records
                  .where((r) => r.letter == letter)
                  .toList();
              return (
                letter,
                attempts.where((r) => r.correct).length,
                attempts.length,
              );
            })
            .toList()
          ..sort((a, b) {
            final byMistakes = (b.$3 - b.$2).compareTo(a.$3 - a.$2);
            return byMistakes == 0 ? a.$1.compareTo(b.$1) : byMistakes;
          });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<ProgressPeriod>(
          key: const ValueKey('metrics-period'),
          initialValue: _period,
          decoration: InputDecoration(labelText: tr('Time period')),
          isExpanded: true,
          items: ProgressPeriod.values
              .map((p) => DropdownMenuItem(value: p, child: Text(tr(p.label))))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _period = value);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const ValueKey('metrics-mode'),
          initialValue: _mode?.name ?? 'all',
          decoration: InputDecoration(labelText: tr('Practice mode')),
          isExpanded: true,
          items: [
            DropdownMenuItem(value: 'all', child: Text(tr('All modes'))),
            for (final mode in PracticeMode.values)
              DropdownMenuItem(value: mode.name, child: Text(mode.label)),
          ],
          onChanged: (value) => setState(
            () => _mode = PracticeMode.values
                .where((m) => m.name == value)
                .firstOrNull,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const ValueKey('metrics-group'),
          initialValue: _characters ?? 'all',
          decoration: InputDecoration(labelText: tr('Character group')),
          isExpanded: true,
          items: groups.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key ?? 'all',
                  child: Text(
                    tr(e.value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => _characters = value == 'all' ? null : value),
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            'Rolling 24 hours, 7, 30 or 365 days. Overview above stays all-time.',
          ),
          style: TextStyle(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 16),
        Text(
          tr('${summary.correct} / ${summary.attempts} correct'),
          key: const ValueKey('metrics-score'),
          style: TextStyle(
            fontSize: 20,
            color: ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            metric(
              tr('Accuracy'),
              summary.accuracy == null ? '—' : '${summary.accuracy}%',
            ),
            metric(
              tr('Characters correct'),
              '${summary.letters.length} / ${characters.length}',
            ),
            metric(tr('Practices'), '${summary.sessions}'),
            metric(tr('Active days'), '${summary.activeDays}'),
            metric(tr('Current correct streak'), '${summary.streak}'),
          ],
        ),
        if (summary.attempts == 0)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(tr('No answers match these filters yet.')),
          ),
        if (widget.history.hasEarlierResults)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              tr(
                'Earlier results are retained in overall totals. Mode, date, chapter scores and detailed metrics start with this update.',
              ),
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            tr('Character details'),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            tr('Most missed first'),
            style: TextStyle(fontSize: 10, color: muted),
          ),
          const SizedBox(height: 6),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      row.$1,
                      style: TextStyle(fontSize: 18, color: accent),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tr('${row.$2} / ${row.$3} correct'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '${(row.$2 / row.$3 * 100).round()}%',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
