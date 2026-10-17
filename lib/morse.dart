const morse = <String, String>{
  'A': '.-',
  'B': '-...',
  'C': '-.-.',
  'D': '-..',
  'E': '.',
  'F': '..-.',
  'G': '--.',
  'H': '....',
  'I': '..',
  'J': '.---',
  'K': '-.-',
  'L': '.-..',
  'M': '--',
  'N': '-.',
  'O': '---',
  'P': '.--.',
  'Q': '--.-',
  'R': '.-.',
  'S': '...',
  'T': '-',
  'U': '..-',
  'V': '...-',
  'W': '.--',
  'X': '-..-',
  'Y': '-.--',
  'Z': '--..',
  '0': '-----',
  '1': '.----',
  '2': '..---',
  '3': '...--',
  '4': '....-',
  '5': '.....',
  '6': '-....',
  '7': '--...',
  '8': '---..',
  '9': '----.',
};
const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
String decode(String code) =>
    morse.entries.where((e) => e.value == code).firstOrNull?.key ?? '';
String encode(String text) => text
    .toUpperCase()
    .split('')
    .map((c) => c == ' ' ? '/' : morse[c] ?? '')
    .where((c) => c.isNotEmpty)
    .join(' ');
String symbols(String code) => code.replaceAll('.', '·').replaceAll('-', '−');
bool validPrefix(String code) =>
    morse.values.any((value) => value.startsWith(code));
String classifyPress(int duration, int threshold) =>
    duration < threshold ? '.' : '-';

class MorseNode {
  final String code;
  final String letter;
  final double x;
  final double y;
  MorseNode(this.code, this.letter, this.x, this.y);
}

List<MorseNode> treeNodes(bool numbers) {
  final codes = <String>{''};
  for (final entry in morse.entries) {
    if (!numbers && !alphabet.contains(entry.key)) continue;
    for (var i = 1; i <= entry.value.length; i++) {
      codes.add(entry.value.substring(0, i));
    }
  }
  // Pack existing leaves instead of reserving columns for empty branches.
  // This keeps every letter (and optional number) readable in a phone viewport.
  final positions = <String, double>{};
  var leafCount = 0;
  double position(String code) {
    final children = [
      '.',
      '-',
    ].map((signal) => code + signal).where(codes.contains).toList();
    if (children.isEmpty) return positions[code] = leafCount++ + .5;
    final childPositions = children.map(position).toList();
    var x = childPositions.reduce((a, b) => a + b) / childPositions.length;
    if (children.length == 1) x += children.first.endsWith('.') ? .3 : -.3;
    return positions[code] = x;
  }

  position('');
  final sorted = codes.toList()..sort((a, b) => a.length.compareTo(b.length));
  return sorted.map((code) {
    final letter = decode(code);
    return MorseNode(
      code,
      numbers || alphabet.contains(letter) ? letter : '',
      20 + positions[code]! * 920 / leafCount,
      30 + code.length * 65.0,
    );
  }).toList();
}
