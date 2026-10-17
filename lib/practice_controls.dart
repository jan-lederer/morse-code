import 'package:flutter/material.dart';

enum PracticeMode {
  send('Send signals'),
  type('Type an answer'),
  choices('4 choices');

  const PracticeMode(this.label);
  final String label;
}

class PracticeStats extends StatelessWidget {
  const PracticeStats({
    super.key,
    required this.correct,
    required this.attempts,
    required this.learned,
  });
  final int correct, attempts, learned;

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
        _stat('$learned', 'Practiced'),
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
  });
  final PracticeMode mode;
  final String group;
  final Map<String, String> groups;
  final ValueChanged<PracticeMode> onMode;
  final ValueChanged<String> onGroup;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: Row(
      children: [
        Expanded(
          child: DropdownButton<PracticeMode>(
            key: const ValueKey('practice-mode'),
            value: mode,
            isExpanded: true,
            underline: const SizedBox(),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            items: PracticeMode.values
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(
                      m.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onMode(value);
            },
          ),
        ),
        const SizedBox(width: 12),
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
