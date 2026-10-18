import 'morse.dart';
import 'practice_controls.dart';

enum ProgressPeriod {
  all('All time', null),
  day('Last day', 1),
  week('Last week', 7),
  month('Last month', 30),
  year('Last year', 365);

  const ProgressPeriod(this.label, this.days);
  final String label;
  final int? days;
}

class PracticeRecord {
  const PracticeRecord({
    required this.id,
    required this.at,
    required this.mode,
    required this.letter,
    required this.correct,
    required this.session,
    required this.hinted,
  });
  final String id, letter, session;
  final DateTime at;
  final PracticeMode mode;
  final bool correct, hinted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toUtc().millisecondsSinceEpoch,
    'mode': mode.name,
    'letter': letter,
    'correct': correct,
    'session': session,
    'hinted': hinted,
  };

  static PracticeRecord? parse(dynamic value) {
    if (value is! Map) return null;
    final mode = PracticeMode.values
        .where((m) => m.name == value['mode'])
        .firstOrNull;
    if (mode == null ||
        value['id'] is! String ||
        value['session'] is! String ||
        value['at'] is! int ||
        !morse.containsKey(value['letter']) ||
        value['correct'] is! bool ||
        value['hinted'] is! bool) {
      return null;
    }
    try {
      return PracticeRecord(
        id: value['id'],
        at: DateTime.fromMillisecondsSinceEpoch(value['at'], isUtc: true),
        mode: mode,
        letter: value['letter'],
        correct: value['correct'],
        session: value['session'],
        hinted: value['hinted'],
      );
    } catch (_) {
      return null;
    }
  }
}

class MasteryRecord {
  const MasteryRecord({
    required this.id,
    required this.at,
    required this.mode,
    required this.item,
    required this.kind,
    required this.correct,
  });
  final String id, item, kind;
  final DateTime at;
  final PracticeMode mode;
  final bool correct;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toUtc().millisecondsSinceEpoch,
    'mode': mode.name,
    'item': item,
    'kind': kind,
    'correct': correct,
  };

  static MasteryRecord? parse(dynamic value) {
    if (value is! Map) return null;
    final mode = PracticeMode.values
        .where((m) => m.name == value['mode'])
        .firstOrNull;
    if (mode == null ||
        value['id'] is! String ||
        value['at'] is! int ||
        value['item'] is! String ||
        value['kind'] is! String ||
        !['word', 'sentence'].contains(value['kind']) ||
        value['correct'] is! bool) {
      return null;
    }
    return MasteryRecord(
      id: value['id'],
      at: DateTime.fromMillisecondsSinceEpoch(value['at'], isUtc: true),
      mode: mode,
      item: value['item'],
      kind: value['kind'],
      correct: value['correct'],
    );
  }
}

/// Three-step mastery. Single-character items need a short streak to advance;
/// phrase items can opt into one level per correct answer or mistake.
int masteryLevel(Iterable<bool> outcomes, {bool singleStep = false}) {
  var level = 0;
  var streak = 0;
  for (final correct in outcomes) {
    if (singleStep) {
      level = (level + (correct ? 1 : -1)).clamp(0, 2);
      continue;
    }
    if (!correct) {
      level = (level - 1).clamp(0, 2);
      streak = 0;
      continue;
    }
    streak++;
    if ((level == 0 && streak >= 2) || (level == 1 && streak >= 3)) {
      level++;
      streak = 0;
    }
  }
  return level;
}

class ProgressSummary {
  ProgressSummary(
    this.records, {
    this.earlierAttempts = 0,
    this.earlierCorrect = 0,
    Set<String> earlierLetters = const {},
  }) : letters = {
         ...earlierLetters,
         ...records.where((r) => r.correct).map((r) => r.letter),
       };
  final List<PracticeRecord> records;
  final int earlierAttempts, earlierCorrect;
  final Set<String> letters;
  int get attempts => earlierAttempts + records.length;
  int get correct => earlierCorrect + records.where((r) => r.correct).length;
  int? get accuracy =>
      attempts == 0 ? null : (correct / attempts * 100).round();
  int get sessions => records.map((r) => r.session).toSet().length;
  int get activeDays => records
      .map((r) {
        final local = r.at.toLocal();
        return DateTime(local.year, local.month, local.day);
      })
      .toSet()
      .length;
  int get unassistedCorrect =>
      records.where((r) => r.correct && !r.hinted).length;
  int get streak {
    final ordered = [...records]..sort((a, b) => b.at.compareTo(a.at));
    return ordered.takeWhile((r) => r.correct).length;
  }
}

class ProgressHistory {
  ProgressHistory({
    this.earlierAttempts = 0,
    this.earlierCorrect = 0,
    Set<String>? earlierLetters,
    List<PracticeRecord>? records,
    List<MasteryRecord>? masteryRecords,
  }) : earlierLetters = earlierLetters ?? {},
       records = records ?? [],
       masteryRecords = masteryRecords ?? [];
  final int earlierAttempts, earlierCorrect;
  final Set<String> earlierLetters;
  final List<PracticeRecord> records;
  final List<MasteryRecord> masteryRecords;
  bool get hasEarlierResults =>
      earlierAttempts > 0 || earlierLetters.isNotEmpty;
  int get totalAttempts => earlierAttempts + records.length;
  int get totalCorrect =>
      earlierCorrect + records.where((r) => r.correct).length;
  Set<String> get allLetters => {
    ...earlierLetters,
    ...records.where((r) => r.correct).map((r) => r.letter),
  };

  factory ProgressHistory.fromSaved(Map<String, dynamic> data) {
    final raw = data['progress'];
    final current = raw is Map && raw['version'] is int && raw['version'] >= 1;
    final source = current ? raw : data;
    final attempts = source['attempts'] is int
        ? (source['attempts'] as int).clamp(0, 1 << 53)
        : 0;
    final correct = source['correct'] is int
        ? (source['correct'] as int).clamp(0, attempts)
        : 0;
    final letters = (source['learned'] is List ? source['learned'] as List : [])
        .whereType<String>()
        .where(morse.containsKey)
        .toSet();
    final seen = <String>{};
    final records = <PracticeRecord>[];
    if (current && raw['records'] is List) {
      for (final item in raw['records']) {
        final record = PracticeRecord.parse(item);
        if (record != null && seen.add(record.id)) records.add(record);
      }
    }
    final seenMastery = <String>{};
    final masteryRecords = <MasteryRecord>[];
    if (current && raw['mastery'] is List) {
      for (final item in raw['mastery']) {
        final record = MasteryRecord.parse(item);
        if (record != null && seenMastery.add(record.id)) {
          masteryRecords.add(record);
        }
      }
    }
    return ProgressHistory(
      earlierAttempts: attempts,
      earlierCorrect: correct,
      earlierLetters: letters,
      records: records,
      masteryRecords: masteryRecords,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'attempts': earlierAttempts,
    'correct': earlierCorrect,
    'learned': earlierLetters.toList(),
    'records': records.map((r) => r.toJson()).toList(),
    'mastery': masteryRecords.map((r) => r.toJson()).toList(),
  };

  void merge(Iterable<PracticeRecord> pending) {
    final seen = records.map((r) => r.id).toSet();
    records.addAll(pending.where((r) => seen.add(r.id)));
  }

  ProgressSummary summary({
    ProgressPeriod period = ProgressPeriod.all,
    PracticeMode? mode,
    String? characters,
    DateTime? now,
  }) {
    final end = (now ?? DateTime.now()).toUtc();
    final start = period.days == null
        ? null
        : end.subtract(Duration(days: period.days!));
    final selected = records
        .where(
          (r) =>
              !r.at.isAfter(end) &&
              (start == null || !r.at.isBefore(start)) &&
              (mode == null || mode == r.mode) &&
              (characters == null || characters.contains(r.letter)),
        )
        .toList();
    // Old saves have neither timestamps nor mode attribution; do not invent it.
    final includeEarlier = period == ProgressPeriod.all && mode == null;
    final includeEarlierScore = includeEarlier && characters == null;
    return ProgressSummary(
      selected,
      earlierAttempts: includeEarlierScore ? earlierAttempts : 0,
      earlierCorrect: includeEarlierScore ? earlierCorrect : 0,
      earlierLetters: includeEarlier
          ? earlierLetters
                .where((c) => characters == null || characters.contains(c))
                .toSet()
          : {},
    );
  }
}
