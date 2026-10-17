import 'package:flutter/material.dart';

import 'morse.dart';
import 'morse_tree.dart';
import 'morse_key.dart';

/// The tree and key share a bounded viewport, even on short phones or landscape.
class TouchWorkspace extends StatelessWidget {
  final bool dark, numbers, pressed, holdDash, pending;
  final String path, message;
  final VoidCallback onNumbers,
      onHelp,
      onDot,
      onDash,
      onCommit,
      onSpace,
      onDelete,
      onClear;
  final ValueChanged<MorseNode> onSelect;
  final PointerDownEventListener onDown;
  final PointerUpEventListener onUp;
  final PointerCancelEventListener onCancel;
  const TouchWorkspace({
    super.key,
    required this.dark,
    required this.numbers,
    required this.path,
    required this.message,
    required this.pressed,
    required this.holdDash,
    required this.pending,
    required this.onNumbers,
    required this.onHelp,
    required this.onSelect,
    required this.onDown,
    required this.onUp,
    required this.onCancel,
    required this.onDot,
    required this.onDash,
    required this.onCommit,
    required this.onSpace,
    required this.onDelete,
    required this.onClear,
  });

  static const accent = Color(0xFFE77860);
  Color get ink => dark ? const Color(0xFFF0F1EC) : const Color(0xFF26302F);
  Color get muted => dark ? const Color(0xFF9AA4A0) : const Color(0xFF747E77);
  Color get line => dark ? const Color(0xFF353D3B) : const Color(0xFFE4E7DC);
  Color get surface => dark ? const Color(0xFF202627) : Colors.white;
  Color get soft => dark ? const Color(0xFF322B28) : const Color(0xFFFFF1EB);
  Text label(
    String text, {
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double? spacing,
  }) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: size,
      color: color ?? ink,
      fontWeight: weight,
      letterSpacing: spacing,
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    child: LayoutBuilder(
      builder: (context, c) {
        final landscape = c.maxWidth > c.maxHeight * 1.15;
        final tree = Container(
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: Column(
            children: [
              SizedBox(
                height: 38,
                child: Row(
                  children: [
                    Expanded(
                      child: label(
                        'Morse tree',
                        size: 17,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Tooltip(
                      message: numbers ? 'Hide numbers' : 'Show numbers',
                      child: TextButton(
                        onPressed: onNumbers,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: label(
                          '0–9',
                          size: 12,
                          color: numbers ? accent : muted,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'How it works',
                      onPressed: onHelp,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.info_outline, size: 18, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bounds) => MorseTree(
                    numbers: numbers,
                    path: path,
                    dark: dark,
                    height: bounds.maxHeight,
                    onSelect: onSelect,
                  ),
                ),
              ),
              SizedBox(
                height: 34,
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: label(
                        path.isEmpty
                            ? '—'
                            : decode(path).isEmpty
                            ? '?'
                            : decode(path),
                        size: 25,
                        color: accent,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: label(
                        path.isEmpty ? 'Ready when you are' : symbols(path),
                        size: path.isEmpty ? 10 : 20,
                        color: path.isEmpty ? muted : ink,
                        spacing: path.isEmpty ? 0 : 2,
                      ),
                    ),
                    label(
                      pressed
                          ? (holdDash ? 'HOLD · DASH' : 'TAP · DOT')
                          : pending
                          ? 'PAUSE TO WRITE'
                          : 'YOUR SIGNAL',
                      size: 8,
                      color: muted,
                      spacing: .6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        final controls = Column(
          children: [
            messageBar(),
            const SizedBox(height: 7),
            Expanded(child: touchKey()),
            const SizedBox(height: 7),
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(child: manualButton('Dot', Icons.circle, onDot)),
                  const SizedBox(width: 7),
                  Expanded(child: manualButton('Dash', Icons.remove, onDash)),
                  const SizedBox(width: 7),
                  IconButton.filledTonal(
                    tooltip: 'Finish letter',
                    onPressed: onCommit,
                    style: IconButton.styleFrom(
                      backgroundColor: surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    icon: Icon(Icons.check, size: 20, color: ink),
                  ),
                ],
              ),
            ),
          ],
        );
        if (landscape) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: tree),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: controls),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 3, child: tree),
            const SizedBox(height: 10),
            Expanded(flex: 2, child: controls),
          ],
        );
      },
    ),
  );

  Widget manualButton(String text, IconData icon, VoidCallback onTap) =>
      FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(text),
        style: FilledButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget messageBar() => Container(
    height: 46,
    padding: const EdgeInsets.only(left: 12, right: 2),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: line),
    ),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            label: 'Your message: $message',
            child: Text(
              message.isEmpty ? 'Your message…' : message,
              key: const ValueKey('compact-message'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: message.isEmpty ? 12 : 20,
                color: message.isEmpty ? muted : ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Add space',
          onPressed: onSpace,
          icon: Icon(Icons.space_bar, size: 18, color: muted),
        ),
        IconButton(
          tooltip: 'Delete last signal or character',
          onPressed: onDelete,
          icon: Icon(Icons.backspace_outlined, size: 17, color: muted),
        ),
        IconButton(
          tooltip: 'Clear message',
          onPressed: onClear,
          icon: Icon(Icons.delete_outline, size: 18, color: muted),
        ),
      ],
    ),
  );

  Widget touchKey() => MorseKey(
    dark: dark,
    pressed: pressed,
    holdDash: holdDash,
    onDown: onDown,
    onUp: onUp,
    onCancel: onCancel,
  );
}
