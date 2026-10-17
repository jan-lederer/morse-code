import 'package:flutter/material.dart';

enum PracticeMode {
  send('Send signals'),
  type('Type an answer'),
  choices('4 choices'),
  sendChoices('Send · 4 choices');

  const PracticeMode(this.label);
  final String label;
}

class PracticeStats extends StatelessWidget {
  const PracticeStats({
    super.key,
    required this.correct,
    required this.attempts,
  });
  final int correct, attempts;

  Widget _stat(String value, String title, {Key? key}) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          key: key,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
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
    child: Row(
      children: [
        _stat('$correct', 'Correct', key: const ValueKey('practice-correct')),
        _stat(
          attempts == 0 ? '0%' : '${(correct / attempts * 100).round()}%',
          'Accuracy',
        ),
        _stat('$attempts', 'Answers'),
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
  });
  final PracticeMode mode;
  final String group;
  final Map<String, String> groups;
  final ValueChanged<PracticeMode> onMode;
  final ValueChanged<String> onGroup;
  final VoidCallback? onNewSession;

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
              onPressed: () => onMode(
                sending
                    ? (_choices ? PracticeMode.sendChoices : PracticeMode.send)
                    : (_choices ? PracticeMode.choices : PracticeMode.type),
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
          onSelectionChanged: (value) => onMode(
            _sending
                ? (value.first ? PracticeMode.sendChoices : PracticeMode.send)
                : (value.first ? PracticeMode.choices : PracticeMode.type),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: DropdownButton<String>(
            key: const ValueKey('practice-group'),
            value: group,
            isExpanded: true,
            underline: const SizedBox(),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            items: groups.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onGroup(value);
            },
          ),
        ),
        if (onNewSession != null)
          IconButton(
            tooltip: 'New practice',
            onPressed: onNewSession,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(Icons.refresh, size: 19),
          ),
      ],
    ),
  );
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
