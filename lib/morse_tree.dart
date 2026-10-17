import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'morse.dart';

const _accent = Color(0xFFE77860);

/// A fitted diagram: its bounds never depend on the currently selected path.
class MorseTree extends StatelessWidget {
  final bool numbers, dark;
  final String path;
  final double? height;
  final ValueChanged<MorseNode> onSelect;
  const MorseTree({
    super.key,
    required this.numbers,
    required this.path,
    required this.dark,
    required this.onSelect,
    this.height,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final width = c.maxWidth;
      final treeHeight = height ?? (numbers ? 350.0 : 290.0);
      final nodes = treeNodes(numbers);
      final scaleX = width / 960;
      final scaleY = (treeHeight - 32) / (numbers ? 325 : 260);
      final levelSizes = <int, double>{};
      for (var depth = 0; depth <= (numbers ? 5 : 4); depth++) {
        final row = nodes.where((n) => n.code.length == depth).toList()
          ..sort((a, b) => a.x.compareTo(b.x));
        var spacing = width;
        for (var i = 1; i < row.length; i++) {
          spacing = math.min(spacing, (row[i].x - row[i - 1].x) * scaleX);
        }
        final verticalSpacing = (treeHeight - 32) / (numbers ? 5 : 4);
        levelSizes[depth] = math.min(
          30,
          math.min(spacing * .85, verticalSpacing * .9),
        );
      }
      double nodeSize(MorseNode node) => levelSizes[node.code.length]!;
      Offset position(MorseNode node) =>
          Offset(node.x * scaleX, 16 + (node.y - 30) * scaleY);
      return SizedBox(
        key: const ValueKey('whole-morse-tree'),
        width: width,
        height: treeHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: Size(width, treeHeight),
              painter: TreePainter(
                nodes: nodes,
                path: path,
                dark: dark,
                scaleX: scaleX,
                scaleY: scaleY,
                nodeSize: nodeSize,
              ),
            ),
            Positioned(
              left: 4,
              top: 0,
              child: Text(
                '· DOT / LEFT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: dark
                      ? const Color(0xFFB6C3B0)
                      : const Color(0xFF617052),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 0,
              child: Text(
                '− DASH / RIGHT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: dark
                      ? const Color(0xFFB6C3B0)
                      : const Color(0xFF617052),
                ),
              ),
            ),
            ...nodes.map((node) {
              final current = path.isNotEmpty && node.code == path;
              final active = path.isNotEmpty && path.startsWith(node.code);
              final size = nodeSize(node);
              final center = position(node);
              return Positioned(
                left: center.dx - size / 2,
                top: center.dy - size / 2,
                child: Semantics(
                  label: node.code.isEmpty
                      ? 'Morse tree root'
                      : '${node.letter}, ${node.code.split('').map((c) => c == '.' ? 'dot' : 'dash').join(' ')}',
                  button: node.letter.isNotEmpty,
                  selected: current,
                  child: Tooltip(
                    message: node.letter.isEmpty
                        ? 'Start here'
                        : '${node.letter}  ${symbols(node.code)}',
                    child: InkWell(
                      onTap: node.letter.isEmpty ? null : () => onSelect(node),
                      customBorder: const CircleBorder(),
                      child: AnimatedContainer(
                        key: ValueKey('tree-node-${node.code}'),
                        duration: const Duration(milliseconds: 100),
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: current
                              ? _accent
                              : active
                              ? (dark
                                    ? const Color(0xFF503D32)
                                    : const Color(0xFFFCE4D7))
                              : dark
                              ? const Color(0xFF26312B)
                              : const Color(0xFFF2F3E9),
                          border: Border.all(
                            color: active
                                ? _accent
                                : dark
                                ? const Color(0xFF7D8A70)
                                : const Color(0xFFBCC6A8),
                            width: current ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          node.code.isEmpty
                              ? 'dit'
                              : node.letter.isEmpty
                              ? '·'
                              : node.letter,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: node.code.isEmpty
                                ? 9
                                : math.min(13, size * .69),
                            fontWeight: FontWeight.w700,
                            color: current
                                ? Colors.white
                                : dark
                                ? const Color(0xFFE0E8D8)
                                : const Color(0xFF435331),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

class TreePainter extends CustomPainter {
  final List<MorseNode> nodes;
  final String path;
  final bool dark;
  final double scaleX, scaleY;
  final double Function(MorseNode) nodeSize;
  TreePainter({
    required this.nodes,
    required this.path,
    required this.dark,
    required this.scaleX,
    required this.scaleY,
    required this.nodeSize,
  });
  @override
  void paint(Canvas canvas, Size size) {
    for (final node in nodes.where((n) => n.code.isNotEmpty)) {
      final parent = nodes.firstWhere(
        (n) => n.code == node.code.substring(0, node.code.length - 1),
      );
      final active = path.isNotEmpty && path.startsWith(node.code);
      final paint = Paint()
        ..color = active
            ? _accent
            : dark
            ? const Color(0xFF6E7E60)
            : const Color(0xFFBAC5A6)
        ..strokeWidth = active ? 2.6 : 1.35
        ..style = PaintingStyle.stroke;
      final start = Offset(
        parent.x * scaleX,
        16 + (parent.y - 30) * scaleY + nodeSize(parent) / 2,
      );
      final end = Offset(
        node.x * scaleX,
        16 + (node.y - 30) * scaleY - nodeSize(node) / 2,
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(TreePainter old) =>
      old.path != path ||
      old.dark != dark ||
      old.nodes.length != nodes.length ||
      old.scaleX != scaleX ||
      old.scaleY != scaleY;
}
