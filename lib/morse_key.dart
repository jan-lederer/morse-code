import 'package:flutter/material.dart';

/// Shared touch key for the tree and practice views.
class MorseKey extends StatelessWidget {
  final bool dark, pressed, holdDash;
  final PointerDownEventListener onDown;
  final PointerUpEventListener onUp;
  final PointerCancelEventListener onCancel;
  const MorseKey({
    super.key,
    required this.dark,
    required this.pressed,
    required this.holdDash,
    required this.onDown,
    required this.onUp,
    required this.onCancel,
  });
  static const accent = Color(0xFFE77860);
  Color get ink => dark ? const Color(0xFFF0F1EC) : const Color(0xFF26302F);
  Color get muted => dark ? const Color(0xFF9AA4A0) : const Color(0xFF747E77);
  Color get soft => dark ? const Color(0xFF322B28) : const Color(0xFFFFF1EB);
  Text label(
    String text, {
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: size, color: color ?? ink, fontWeight: weight),
  );
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Morse key. Tap for dot. Hold for dash.',
    button: true,
    child: Listener(
      onPointerDown: onDown,
      onPointerUp: onUp,
      onPointerCancel: onCancel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          key: const ValueKey('touch-morse-key'),
          duration: const Duration(milliseconds: 90),
          width: double.infinity,
          decoration: BoxDecoration(
            color: pressed ? accent : soft,
            border: Border.all(color: accent.withValues(alpha: .5), width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: LayoutBuilder(
            builder: (context, bounds) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                label(
                  pressed ? (holdDash ? '−' : '·') : '· −',
                  size: bounds.maxHeight < 65 ? 28 : 40,
                  color: pressed ? Colors.white : accent,
                  weight: FontWeight.w500,
                ),
                const SizedBox(width: 17),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label(
                        pressed
                            ? (holdDash ? 'Keep holding…' : 'Make your signal')
                            : 'Tap. Hold. Connect.',
                        size: 13,
                        color: pressed ? Colors.white : ink,
                        weight: FontWeight.w600,
                      ),
                      if (bounds.maxHeight >= 50) ...[
                        const SizedBox(height: 5),
                        label(
                          'Tap · dot   /   Hold · dash',
                          size: 10,
                          color: pressed ? Colors.white70 : muted,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
