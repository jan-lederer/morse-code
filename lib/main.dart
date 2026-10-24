import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'morse.dart';
import 'morse_tree.dart';
import 'touch_workspace.dart';
import 'practice_workspace.dart';
import 'platform_service.dart';
import 'signal_feedback.dart';
import 'recognition_workspace.dart';
import 'practice_controls.dart';
import 'practice_content.dart';
import 'progress_history.dart';
import 'learn_overview.dart';
import 'app_palette.dart';
import 'app_strings.dart';
import 'template_icons.dart';


enum _ExamChoice { resume, startNew }

class _SavedExam {
  const _SavedExam({
    required this.question,
    required this.mistakes,
    required this.mode,
    required this.remainingModes,
    required this.target,
    required this.sendIndex,
    required this.pendingAdvance,
  });

  final int question, mistakes, sendIndex;
  final PracticeMode mode;
  final List<PracticeMode> remainingModes;
  final String target;
  final bool pendingAdvance;

  Map<String, Object?> toJson() => {
    'question': question,
    'mistakes': mistakes,
    'mode': mode.name,
    'remainingModes': remainingModes.map((mode) => mode.name).toList(),
    'target': target,
    'sendIndex': sendIndex,
    'pendingAdvance': pendingAdvance,
  };

  static _SavedExam? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    try {
      final question = value['question'];
      final mistakes = value['mistakes'];
      final sendIndex = value['sendIndex'];
      final target = value['target'];
      final modeName = value['mode'];
      final remainingNames = value['remainingModes'];
      final pendingAdvance = value['pendingAdvance'];
      if (question is! int || question < 1 || question > 20) return null;
      if (mistakes is! int || mistakes < 0 || mistakes >= 3) return null;
      if (sendIndex is! int || sendIndex != 0) return null;
      if (target is! String || !morse.containsKey(target)) return null;
      if (modeName is! String || remainingNames is! List) return null;
      if (pendingAdvance is! bool ||
          (pendingAdvance && question == 20) ||
          value['status'] == 'passed' ||
          value['status'] == 'failed') {
        return null;
      }
      final mode = PracticeMode.values.byName(modeName);
      final remainingModes = remainingNames
          .map((name) => PracticeMode.values.byName(name as String))
          .toList();
      if (remainingModes.length != 20 - question) return null;
      return _SavedExam(
        question: question,
        mistakes: mistakes,
        mode: mode,
        remainingModes: remainingModes,
        target: target,
        sendIndex: sendIndex,
        pendingAdvance: pendingAdvance,
      );
    } catch (_) {
      return null;
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DitApp());
}

class DitApp extends StatefulWidget {
  const DitApp({super.key, this.randomSeed});
  final int? randomSeed;
  @override
  State<DitApp> createState() => _DitAppState();
}

class _DitAppState extends State<DitApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  bool get dark =>
      _themeMode == ThemeMode.dark ||
      (_themeMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);
  bool sound = true,
      vibration = false,
      numbers = false,
      pressed = false,
      playing = false;
  int page = 1, pace = 1, attempts = 0, correct = 0;
  String appLanguage = 'EN';
  final learned = <String>{};
  ProgressHistory history = ProgressHistory();
  int examsPassed = 0;
  int sessionAttempts = 0, sessionCorrect = 0, sessionSerial = 0;
  String sessionId = DateTime.now().microsecondsSinceEpoch.toString();
  String sequence = '',
      lastCode = '',
      message = '',
      target = 'E',
      group = alphabet,
      result = '',
      search = '',
      selectedLetter = '';
  bool hideHint = false;
  int sendIndex = 0;
  int examQuestion = 0, examMistakes = 0;
  String examStatus = '';
  List<PracticeMode> examModes = [];
  _SavedExam? _savedExam;
  String? _shownPassedExamSession;
  PracticeMode practiceMode = PracticeMode.send;
  bool get examSelected => group == '@exam';
  bool get examRunning => examSelected && examStatus.isEmpty;
  String appVersion = '';
  Timer? commitTimer, holdTimer, advanceTimer;
  final signalFeedback = SignalFeedback(DeviceService.tone);
  late final math.Random _sendChoiceRandom;
  String? _sendChoiceKey;
  List<String> _sendChoices = [];
  SignalTone? inputTone;
  bool practiceSuspended = false, dialogOpen = false;
  int? walkthroughStep;
  int _walkthroughTapAnimationSerial = 0;
  int _walkthroughSpotlightAnimationSerial = 0;
  bool _walkthroughTransitionPending = false;
  Timer? _walkthroughTapTimer;
  final walkthroughTabKeys = List<GlobalKey>.generate(4, (_) => GlobalKey());
  final walkthroughLearnKey = GlobalKey();
  final walkthroughTreeKey = GlobalKey();
  final walkthroughPracticeKey = GlobalKey();
  final walkthroughPracticeControlsKey = GlobalKey();
  final walkthroughAlphabetKey = GlobalKey();
  Rect? walkthroughTargetRect;
  Rect? _walkthroughFromTargetRect;
  List<_WalkthroughStop> get _walkthroughStops => [
    _WalkthroughStop(
      page: 0,
      target: walkthroughTabKeys[0],
      isTab: true,
      title: 'Learn tab',
      description: 'Select this highlighted tab to open your learning overview and progress.',
    ),
    _WalkthroughStop(
      page: 0,
      target: walkthroughLearnKey,
      title: 'Proficiency bars',
      description: 'See how well you know letters, words, and sentences.',
    ),
    _WalkthroughStop(
      page: 0,
      target: walkthroughTabKeys[1],
      isTab: true,
      title: 'Morse tree tab',
      description:
          'Select this highlighted tab to open the interactive Morse tree.',
    ),
    _WalkthroughStop(
      page: 1,
      target: walkthroughTreeKey,
      title: 'Explore the tree',
      description:
          'Follow dots and dashes through the branches to find a letter.',
    ),
    _WalkthroughStop(
      page: 1,
      target: walkthroughTabKeys[2],
      isTab: true,
      title: 'Practice tab',
      description:
          'Select this highlighted tab to open listening and sending practice.',
    ),
    _WalkthroughStop(
      page: 2,
      target: walkthroughPracticeControlsKey,
      title: 'Practice settings',
      description: 'Choose a practice mode and select the letters or group you want to work on.',
    ),
    _WalkthroughStop(
      page: 2,
      target: walkthroughPracticeKey,
      title: 'Practice a signal',
      description:
          'Read the prompt, send its Morse pattern, and track your progress.',
    ),
    _WalkthroughStop(
      page: 2,
      target: walkthroughTabKeys[3],
      isTab: true,
      title: 'Alphabet tab',
      description: 'Select this highlighted tab to open the letter and number reference.',
    ),
    _WalkthroughStop(
      page: 3,
      target: walkthroughAlphabetKey,
      title: 'Look up a character',
      description: 'Browse a Morse card or search for a letter or number.',
    ),
  ];
  bool holdDash = false;
  int? activePointer;
  String get visibleCode => pressed
      ? sequence + (holdDash ? '-' : '.')
      : sequence.isEmpty
      ? lastCode
      : sequence;
  int playbackId = 0;
  final messenger = GlobalKey<ScaffoldMessengerState>();
  final scaffold = GlobalKey<ScaffoldState>();
  final focus = FocusNode();
  Color get bg => dark ? const Color(0xFF090E19) : const Color(0xFFF3F6FA);
  Color get surface => dark ? const Color(0xFF131D2D) : Colors.white;
  Color get ink => dark ? const Color(0xFFF1F5FA) : const Color(0xFF172235);
  Color get muted => dark ? const Color(0xFFB6C3D4) : const Color(0xFF56657B);
  Color get line => dark ? const Color(0xFF35465C) : const Color(0xFFDDE5EF);
  Color get appAccent => morseAccentFor(dark);
  Color get appAccentForeground => morseAccentForegroundFor(dark);
  Color get soft => morseAccentSoftFor(dark);
  int get threshold => [320, 230, 170][pace];
  int get gap => [1400, 1000, 700][pace];
  @override
  void initState() {
    super.initState();
    AppStrings.language = 'EN';
    _sendChoiceRandom = math.Random(widget.randomSeed);
    WidgetsBinding.instance.addObserver(this);
    _load();
    DeviceService.version().then((version) {
      if (mounted && version != null) setState(() => appVersion = version);
    });
  }

  Future<void> _load() async {
    final raw = await DeviceService.load();
    if (!mounted || raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final loadedThemeMode = switch (data['themeMode']) {
        'system' => ThemeMode.system,
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ =>
          data.containsKey('dark')
              ? (data['dark'] == true ? ThemeMode.dark : ThemeMode.light)
              : ThemeMode.system,
      };
      setState(() {
        _themeMode = loadedThemeMode;
        sound = data['sound'] != false;
        vibration = data['vibration'] == true;
        hideHint = data['hideHint'] == true;
        pace = (data['pace'] is int ? data['pace'] as int : 1).clamp(0, 2);
        appLanguage = AppStrings.languages.contains(data['language'])
            ? data['language'] as String
            : 'EN';
        AppStrings.language = appLanguage;
        final loaded = ProgressHistory.fromSaved(data);
        loaded.merge(history.records);
        history = loaded;
        examsPassed =
            (data['examsPassed'] is int ? data['examsPassed'] as int : 0).clamp(
              0,
              1 << 31,
            );
        attempts = history.totalAttempts;
        correct = history.totalCorrect;
        learned
          ..clear()
          ..addAll(history.allLetters);
        _savedExam = _SavedExam.fromJson(data['savedExam']);
      });
    } catch (_) {
      /* A damaged preference never prevents startup. */
    }
  }

  void save() {
    if (examSelected) {
      _savedExam = examRunning
          ? _SavedExam(
              question: examQuestion,
              mistakes: examMistakes,
              mode: practiceMode,
              remainingModes: List.of(examModes),
              target: target[sendIndex],
              sendIndex: 0,
              pendingAdvance: result == 'correct',
            )
          : null;
    }
    DeviceService.save(
      jsonEncode({
        'dark': dark,
        'themeMode': _themeMode.name,
        'language': appLanguage,
        'sound': sound,
        'vibration': vibration,
        'hideHint': hideHint,
        'pace': pace,
        'attempts': attempts,
        'correct': correct,
        'learned': learned.toList(),
        'progress': history.toJson(),
        'examsPassed': examsPassed,
        'savedExam': _savedExam?.toJson(),
      }),
    );
  }

  @override
  void dispose() {
    commitTimer?.cancel();
    holdTimer?.cancel();
    advanceTimer?.cancel();
    _walkthroughTapTimer?.cancel();
    playbackId++;
    DeviceService.stopPattern();
    signalFeedback.cancel();
    WidgetsBinding.instance.removeObserver(this);
    focus.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (_themeMode == ThemeMode.system && mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    practiceSuspended = state != AppLifecycleState.resumed;
    if (practiceSuspended) {
      advanceTimer?.cancel();
      cancelInput();
      stopPlayback();
    } else {
      scheduleAdvance();
    }
  }

  void notify(String text) {
    messenger.currentState?.hideCurrentSnackBar();
    messenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(tr(text)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void buzz(int duration) {
    if (vibration) DeviceService.vibrate(duration);
  }

  void stopPlayback() {
    playbackId++;
    DeviceService.stopPattern();
    signalFeedback.cancel();
    inputTone = null;
    if (playing && mounted) setState(() => playing = false);
  }

  Future<void> listen(String code) async {
    if (playing) {
      stopPlayback();
      return;
    }
    cancelInput();
    final id = ++playbackId;
    setState(() {
      playing = true;
    });
    final lead = await DeviceService.playPattern(
      code,
      sound: sound,
      vibration: vibration,
    );
    if (!mounted || id != playbackId) return;
    if (lead < 0) {
      stopPlayback();
      return;
    }
    if (lead > 0) await Future<void>.delayed(Duration(milliseconds: lead));
    for (final char in code.split('')) {
      if (!mounted || id != playbackId) return;
      if (char == '.' || char == '-') {
        await Future<void>.delayed(
          Duration(milliseconds: char == '.' ? 100 : 300),
        );
        if (!mounted || id != playbackId) return;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } else {
        await Future<void>.delayed(
          Duration(milliseconds: char == '/' ? 400 : 200),
        );
      }
    }
    if (mounted && id == playbackId) setState(() => playing = false);
  }

  void cancelInput() {
    commitTimer?.cancel();
    holdTimer?.cancel();
    signalFeedback.cancel();
    inputTone = null;
    activePointer = null;
    if (mounted) {
      setState(() {
        pressed = false;
        sequence = '';
      });
    }
  }

  void begin() {
    if (pressed ||
        dialogOpen ||
        practiceSuspended ||
        (page == 2 && examSelected && examStatus.isNotEmpty) ||
        (page != 1 && page != 2) ||
        (page == 2 &&
            (practiceMode != PracticeMode.send || result == 'correct'))) {
      return;
    }
    commitTimer?.cancel();
    if (playing) stopPlayback();
    setState(() {
      pressed = true;
      holdDash = false;
    });
    holdTimer = Timer(Duration(milliseconds: threshold), () {
      if (mounted && pressed) setState(() => holdDash = true);
    });
    if (sound) {
      inputTone = signalFeedback.press();
    }
    buzz(15);
  }

  void end({bool cancelled = false}) {
    if (!pressed) return;
    holdTimer?.cancel();
    // Commit the same signal shown by the hold preview.
    final signal = holdDash ? '-' : '.';
    if (cancelled) {
      signalFeedback.cancel();
    } else if (inputTone case final tone?) {
      signalFeedback.release(tone, dash: holdDash);
    }
    inputTone = null;
    setState(() => pressed = false);
    if (!cancelled) {
      addSignal(signal);
    } else if (sequence.isNotEmpty) {
      commitTimer = Timer(Duration(milliseconds: gap), commit);
    }
  }

  void pointerDown(PointerDownEvent event) {
    if (activePointer != null || pressed) return;
    activePointer = event.pointer;
    begin();
  }

  void pointerUp(PointerEvent event, {bool cancelled = false}) {
    if (event.pointer != activePointer) return;
    activePointer = null;
    end(cancelled: cancelled);
  }

  void addSignal(String value) {
    commitTimer?.cancel();
    if (page == 2 && examSelected && examStatus.isNotEmpty) return;
    if (page == 2 && result == 'correct') {
      return;
    }
    if (!validPrefix(sequence + value)) {
      notify('That branch ends here. Pause to send, or delete a signal.');
      commitTimer = Timer(Duration(milliseconds: gap), commit);
      return;
    }
    setState(() {
      sequence += value;
      lastCode = '';
    });
    buzz(value == '.' ? 20 : 65);
    commitTimer = Timer(Duration(milliseconds: gap), commit);
  }

  void manual(String signal) {
    if (page == 2 && examSelected && examStatus.isNotEmpty) return;
    if (page == 2 && result == 'correct') return;
    if (playing) stopPlayback();
    addSignal(signal);
    if (sound) {
      final tone = signalFeedback.press();
      signalFeedback.release(tone, dash: signal == '-');
    }
  }

  void commit() {
    commitTimer?.cancel();
    if (page == 2 && examSelected && examStatus.isNotEmpty) return;
    if (sequence.isEmpty) return;
    final letter = decode(sequence);
    if (letter.isEmpty) {
      notify('No character on that branch. Give it another try.');
      setState(() => sequence = '');
      return;
    }
    setState(() {
      lastCode = sequence;
      sequence = '';
      if (page == 1) {
        message = (message + letter);
        if (message.length > 500) {
          message = message.substring(message.length - 500);
        }
      }
      if (page == 2) {
        final expected = target[sendIndex];
        if (letter == expected && sendIndex < target.length - 1) {
          sendIndex++;
          result = 'progress';
        } else {
          final isCorrect = letter == expected;
          _recordPracticeAnswer(
            expected,
            isCorrect,
            itemTarget: target,
            itemComplete: sendIndex == target.length - 1,
          );
          if (!examSelected && isCorrect) {
            sendIndex = 0;
            result = 'correct';
            buzz(65);
          } else if (!examSelected) {
            sendIndex = 0;
            result = letter;
          }
        }
      }
    });
    save();
    scheduleAdvance();
  }

  void pickNode(MorseNode node) {
    cancelInput();
    stopPlayback();
    setState(() {
      sequence = node.code;
      lastCode = '';
    });
    buzz(25);
    // A node is a complete character; keep its path visible while writing it.
    commit();
    if (sound) {
      playNode(node.code);
    }
  }

  Future<void> playNode(String code) async {
    final savedCode = lastCode;
    await listen(code);
    if (mounted && savedCode == lastCode) setState(() {});
  }

  void switchPage(int value) {
    advanceTimer?.cancel();
    cancelInput();
    stopPlayback();
    setState(() {
      if (value == 2 && page != 2) startSession();
      page = value;
      lastCode = '';
      result = '';
    });
    focus.requestFocus();
  }

  void scheduleAdvance() {
    advanceTimer?.cancel();
    if (page != 2 || result != 'correct' || practiceSuspended || dialogOpen) {
      return;
    }
    if (!examSelected &&
        practiceMode != PracticeMode.send &&
        practiceMode != PracticeMode.sendChoices) {
      return;
    }
    advanceTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted &&
          page == 2 &&
          result == 'correct' &&
          examStatus != 'passed' &&
          examStatus != 'failed' &&
          !practiceSuspended &&
          !dialogOpen) {
        nextTarget();
      }
    });
  }

  void nextTarget() {
    advanceTimer?.cancel();
    cancelInput();
    stopPlayback();
    if (examSelected) {
      if (!examRunning || examQuestion >= 20 || examModes.isEmpty) return;
      setState(() {
        _sendChoiceKey = null;
        examQuestion++;
        practiceMode = examModes.removeLast();
        target = _pickPracticeTarget(previous: target);
        sendIndex = 0;
        result = '';
        lastCode = '';
      });
      if (practiceMode == PracticeMode.send ||
          practiceMode == PracticeMode.sendChoices) {
        focus.requestFocus();
      }
      save();
      return;
    }
    final candidates = _practiceTargets().where((c) => c != target).toList();
    setState(() {
      _sendChoiceKey = null;
      target = _weightedTarget(
        candidates.isEmpty ? _practiceTargets() : candidates,
      );
      sendIndex = 0;
      result = '';
      lastCode = '';
    });
  }

  List<String> _practiceTargets() => group == '@words'
      ? practiceWords
      : group == '@sentences'
      ? practiceSentences
      : group == '@exam' || group == '@symbols'
      ? morse.keys.toList()
      : group.split('');

  int _masteryLevel(String item) {
    if (group == '@words' || group == '@sentences') {
      final kind = group == '@words' ? 'word' : 'sentence';
      final outcomes =
          history.masteryRecords
              .where((record) => record.kind == kind && record.item == item)
              .toList()
            ..sort((a, b) => a.at.compareTo(b.at));
      return masteryLevel(
        outcomes.map((record) => record.correct),
        singleStep: true,
      );
    }
    final outcomes =
        history.records.where((record) => record.letter == item).toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    final level = masteryLevel(outcomes.map((record) => record.correct));
    return outcomes.isEmpty && history.earlierLetters.contains(item)
        ? 1
        : level;
  }

  List<int> get _masteryDistribution {
    final counts = [0, 0, 0];
    for (final item in _practiceTargets()) {
      counts[_masteryLevel(item)]++;
    }
    return counts;
  }

  String _weightedTarget(List<String> candidates) {
    if (candidates.length == 1) return candidates.first;
    final weights = candidates.map((item) => [6, 3, 1][_masteryLevel(item)]);
    final total = weights.fold<int>(0, (sum, weight) => sum + weight);
    var pick = math.Random().nextInt(total);
    for (var index = 0; index < candidates.length; index++) {
      pick -= [6, 3, 1][_masteryLevel(candidates[index])];
      if (pick < 0) return candidates[index];
    }
    return candidates.last;
  }

  Text txt(
    String text, {
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? spacing,
    TextAlign? align,
    TextDecoration? decoration,
  }) => Text(
    tr(text),
    textAlign: align,
    style: TextStyle(
      fontSize: size,
      color: color ?? ink,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      decoration: decoration,
    ),
  );
  Widget smallIcon(IconData icon, {double size = 18, Color? color}) =>
      Icon(icon, size: size, color: color ?? muted);
  Widget panel(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(24),
    Color? color,
  }) => Container(
    decoration: BoxDecoration(
      color: color ?? surface,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(20),
    ),
    padding: padding,
    child: child,
  );
  Widget badge(String text, {bool accent = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: accent ? soft : (dark ? line : bg),
      borderRadius: BorderRadius.circular(5),
    ),
    child: txt(
      text,
      size: 9,
      color: accent ? appAccent : muted,
      weight: FontWeight.w700,
      spacing: 1,
    ),
  );
  Widget heading(String title, {Widget? trailing}) => Row(
    children: [
      Expanded(child: txt(title, size: 16, weight: FontWeight.w600)),
      ?trailing,
    ],
  );
  Widget action(
    String text,
    VoidCallback onTap, {
    IconData? icon,
    bool primary = false,
  }) => FilledButton.icon(
    onPressed: onTap,
    icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
    label: Text(tr(text)),
    style: FilledButton.styleFrom(
      backgroundColor: primary ? appAccent : surface,
      foregroundColor: primary ? appAccentForeground : appAccent,
      minimumSize: const Size(48, 48),
      side: primary ? BorderSide.none : BorderSide(color: line),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  );
  Widget logo({bool light = false, double size = 23}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: appAccent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: appAccentForeground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 13,
                height: 6,
                decoration: BoxDecoration(
                  color: appAccentForeground,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text.rich(
        TextSpan(
          text: 'morse',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
            color: light ? Colors.white : ink,
          ),
          children: [
            TextSpan(
              text: '.',
              style: TextStyle(color: appAccent),
            ),
          ],
        ),
      ),
    ],
  );
  ThemeData _themeFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: morseAccentFor(isDark),
          brightness: brightness,
        ).copyWith(
          surface: isDark ? const Color(0xFF131D2D) : Colors.white,
          onSurface: isDark ? const Color(0xFFF1F5FA) : const Color(0xFF172235),
          onSurfaceVariant: isDark
              ? const Color(0xFFB6C3D4)
              : const Color(0xFF56657B),
          outline: isDark ? const Color(0xFF35465C) : const Color(0xFFDDE5EF),
          outlineVariant: isDark
              ? const Color(0xFF35465C)
              : const Color(0xFFDDE5EF),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Roboto',
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF090E19)
          : const Color(0xFFF3F6FA),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? .22 : .14),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'morse',
      debugShowCheckedModeBanner: false,
      locale: Locale(appLanguage.toLowerCase()),
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
        Locale('fr'),
        Locale('es'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: _themeFor(Brightness.light),
      darkTheme: _themeFor(Brightness.dark),
      themeMode: _themeMode,
      scaffoldMessengerKey: messenger,
      home: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1050;
          final shortInput =
              (page == 1 || page == 2) && !wide && constraints.maxHeight < 450;
          return Stack(
            children: [
              Scaffold(
                key: scaffold,
                backgroundColor: bg,
                body: SafeArea(
                  child: Row(
                    children: [
                      if (wide) sidebar(),
                      Expanded(
                        child: Column(
                          children: [
                            topbar(wide, compact: shortInput),
                            Expanded(
                              child: Focus(
                                focusNode: focus,
                                autofocus: true,
                                onKeyEvent: (node, event) {
                                  if (event.logicalKey !=
                                          LogicalKeyboardKey.space ||
                                      (page != 1 && page != 2) ||
                                      (page == 2 &&
                                          practiceMode != PracticeMode.send)) {
                                    return KeyEventResult.ignored;
                                  }
                                  if (event is KeyDownEvent) begin();
                                  if (event is KeyUpEvent) end();
                                  return KeyEventResult.handled;
                                },
                                child: page == 2
                                    ? practicePage()
                                    : page == 1 && !wide
                                    ? touchTreePage()
                                    : SingleChildScrollView(
                                        padding: EdgeInsets.fromLTRB(
                                          wide ? 34 : 20,
                                          wide ? 34 : 25,
                                          wide ? 34 : 20,
                                          24,
                                        ),
                                        child: Center(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 1300,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (page == 0)
                                                  learnPage()
                                                else if (page == 1)
                                                  treePage()
                                                else
                                                  alphabetPage(),
                                                const SizedBox(height: 32),
                                                footer(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: wide
                    ? null
                    : NavigationBar(
                        selectedIndex: page,
                        onDestinationSelected: switchPage,
                        backgroundColor: surface,
                        indicatorColor: soft,
                        height: shortInput ? 56 : 72,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
                        destinations: [
                          NavigationDestination(
                            key: walkthroughTabKeys[0],
                            icon: Icon(Icons.menu_book_outlined),
                            label: 'Learn',
                          ),
                          NavigationDestination(
                            key: walkthroughTabKeys[1],
                            icon: Icon(Icons.account_tree_outlined),
                            label: 'Morse tree',
                          ),
                          NavigationDestination(
                            key: walkthroughTabKeys[2],
                            icon: Icon(Icons.bolt_outlined),
                            label: 'Practice',
                          ),
                          NavigationDestination(
                            key: walkthroughTabKeys[3],
                            icon: Icon(Icons.grid_view_rounded),
                            label: 'Alphabet',
                          ),
                        ],
                      ),
              ),
              if (walkthroughStep != null) _walkthroughOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget sidebar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: line)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          logo(size: 23),
          const SizedBox(height: 10),
          txt(
            'A LITTLE SIGNAL GOES A LONG WAY',
            size: 7,
            color: muted,
            spacing: 1.4,
          ),
          const SizedBox(height: 55),
          txt(
            'YOUR WORKSPACE',
            size: 9,
            color: muted,
            weight: FontWeight.w600,
            spacing: 1.6,
          ),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (i) => Padding(
              key: walkthroughTabKeys[i],
              padding: const EdgeInsets.only(bottom: 7),
              child: Material(
                color: page == i ? soft : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => switchPage(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            [
                              Icons.menu_book_outlined,
                              Icons.account_tree_outlined,
                              Icons.bolt_outlined,
                              Icons.grid_view_rounded,
                            ][i],
                            size: 20,
                            color: page == i ? appAccent : muted,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: txt(
                              ['Learn', 'Morse tree', 'Practice', 'Alphabet'][i],
                              size: 13,
                              color: page == i ? appAccent : ink,
                              weight: page == i
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          if (page == i)
                            Icon(Icons.circle, size: 5, color: appAccent),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                txt('· − ·', size: 30, color: appAccent, spacing: 4),
                const SizedBox(height: 9),
                txt(
                  'A little, every day.',
                  size: 14,
                  color: ink,
                  weight: FontWeight.w700,
                ),
                const SizedBox(height: 8),
                txt(
                  'Great things start with\nthe smallest signals.',
                  size: 11,
                  color: muted,
                  height: 1.7,
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => switchPage(2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: txt(
                              'Keep the rhythm',
                              size: 12,
                              color: appAccent,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Icon(Icons.arrow_forward, size: 18, color: appAccent),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          txt(
            '●  Your own pace. Your own signal.',
            size: 8,
            color: muted,
          ),
        ],
      ),
    );
  }
  Widget topbar(bool wide, {bool compact = false}) => Container(
    height: compact ? 52 : 68,
    padding: EdgeInsets.symmetric(horizontal: wide ? 34 : 20),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        if (wide) ...[
          txt('YOUR WORKSPACE', size: 9, color: muted, spacing: 1.1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: txt('/', color: muted),
          ),
          txt(
            ['Learn', 'Morse tree', 'Practice', 'Alphabet'][page],
            size: 11,
            weight: FontWeight.w600,
          ),
        ] else
          Expanded(
            child: SizedBox(
              height: compact ? 30 : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: logo(),
              ),
            ),
          ),
        const Spacer(),
        if (wide) ...[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: appAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          txt('Made for your own pace', size: 10, color: muted),
          const SizedBox(width: 20),
        ],
        IconButton(
          tooltip: tr('Open settings'),
          onPressed: settingsDialog,
          icon: const Icon(TemplateIcons.settings, size: 21),
        ),
        if (wide) ...[
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFE6E8DD),
            child: txt(
              'you',
              size: 10,
              color: const Color(0xFF687B66),
              weight: FontWeight.w600,
            ),
          ),
        ],
      ],
    ),
  );
  Widget intro(
    String eyebrow,
    String title,
    String subtitle, {
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 29),
    child: LayoutBuilder(
      builder: (context, c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appAccent,
                ),
              ),
              const SizedBox(width: 7),
              txt(
                eyebrow,
                size: 9,
                color: muted,
                spacing: 1.6,
                weight: FontWeight.w600,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: tr(title),
                    style: TextStyle(
                      fontSize: c.maxWidth < 600 ? 32 : 40,
                      height: 1.17,
                      letterSpacing: -1.5,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                    children: [
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: appAccent),
                      ),
                    ],
                  ),
                ),
              ),
              if (c.maxWidth > 700 && trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          txt(subtitle, size: 13, color: muted, height: 1.7),
          if (c.maxWidth <= 700 && trailing != null) ...[
            const SizedBox(height: 12),
            trailing,
          ],
        ],
      ),
    ),
  );
  Widget touchTreePage() => TouchWorkspace(
    walkthroughTreeKey: walkthroughTreeKey,
    dark: dark,
    numbers: numbers,
    path: visibleCode,
    message: message,
    pressed: pressed,
    holdDash: holdDash,
    pending: sequence.isNotEmpty,
    onNumbers: () => setState(() => numbers = !numbers),
    onHelp: howTo,
    onSelect: pickNode,
    onDown: pointerDown,
    onUp: pointerUp,
    onCancel: (event) => pointerUp(event, cancelled: true),
    onDot: () => manual('.'),
    onDash: () => manual('-'),
    onCommit: commit,
    onSpace: () {
      commit();
      setState(() {
        if (message.isNotEmpty && !message.endsWith(' ')) message += ' ';
      });
    },
    onDelete: () {
      commitTimer?.cancel();
      setState(() {
        if (sequence.isNotEmpty) {
          sequence = sequence.substring(0, sequence.length - 1);
        } else if (message.isNotEmpty) {
          message = message.substring(0, message.length - 1);
          lastCode = '';
        }
      });
      if (sequence.isNotEmpty) {
        commitTimer = Timer(Duration(milliseconds: gap), commit);
      }
    },
    onClear: () {
      cancelInput();
      setState(() {
        message = '';
        lastCode = '';
      });
    },
  );

  Widget treePage() => Column(
    children: [
      intro(
        'FOLLOW THE SIGNAL',
        'Connect the dots',
        'Every letter has a path. Find yours, one tap at a time.',
        trailing: action(
          'How it works',
          howTo,
          icon: Icons.info_outline,
        ),
      ),
      LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      treeCard(),
                      const SizedBox(height: 18),
                      messageCard(),
                      const SizedBox(height: 20),
                      gentleTip(),
                    ],
                  ),
                ),
                const SizedBox(width: 22),
                SizedBox(
                  width: 290,
                  child: Column(
                    children: [
                      inputCard(),
                      const SizedBox(height: 18),
                      rhythmTip(),
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              treeCard(),
              const SizedBox(height: 18),
              inputCard(),
              const SizedBox(height: 18),
              messageCard(),
              const SizedBox(height: 18),
              rhythmTip(),
              const SizedBox(height: 18),
              gentleTip(),
            ],
          );
        },
      ),
    ],
  );
  Widget treeCard() => KeyedSubtree(
    key: walkthroughTreeKey,
    child: panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 9,
                  runSpacing: 6,
                  children: [
                    txt('The Morse tree', size: 16, weight: FontWeight.w600),
                    badge('INTERACTIVE', accent: true),
                  ],
                ),
              ),
              Tooltip(
                message: tr('Show numbers'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    txt('0–9', size: 10, color: muted),
                    SizedBox(
                      width: 39,
                      child: Transform.scale(
                        scale: .65,
                        child: Switch(
                          value: numbers,
                          onChanged: (v) => setState(() => numbers = v),
                          activeTrackColor: appAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          txt(
            'Left for a dot. Right for a dash. A letter at every stop.',
            size: 11,
            color: muted,
            height: 1.5,
          ),
          const SizedBox(height: 17),
          MorseTree(
            numbers: numbers,
            path: visibleCode,
            dark: dark,
            onSelect: pickNode,
          ),
          const SizedBox(height: 14),
          Divider(color: line, height: 1),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pan_tool_alt_outlined, size: 13, color: muted),
                  const SizedBox(width: 6),
                  txt('Whole alphabet · tap a letter', size: 9, color: muted),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 14, height: 2, color: appAccent),
                  const SizedBox(width: 6),
                  txt('Your signal’s path', size: 9, color: muted),
                ],
              ),
            ],
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 17),
    ),
  );
  Widget inputCard() {
    final code = visibleCode;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading('Make your signal', trailing: badge('LIVE', accent: true)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: txt(
                    code.isEmpty
                        ? '—'
                        : decode(code).isEmpty
                        ? '?'
                        : decode(code),
                    size: 34,
                    color: code.isEmpty ? muted : ink,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      txt(
                        code.isEmpty ? 'Ready when you are' : symbols(code),
                        size: code.isEmpty ? 10 : 23,
                        color: code.isEmpty ? muted : appAccent,
                        weight: FontWeight.w600,
                        spacing: code.isEmpty ? 0 : 4,
                      ),
                      const SizedBox(height: 5),
                      txt(
                        sequence.isNotEmpty
                            ? 'Keep going or pause to send'
                            : code.isEmpty
                            ? 'Your next letter starts here'
                            : 'Signal received. Keep it going.',
                        size: 8,
                        color: muted,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: pressed ? appAccent : appAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Semantics(
            label: tr('Morse key. Tap for dot. Hold for dash.'),
            button: true,
            child: Listener(
              onPointerDown: pointerDown,
              onPointerUp: pointerUp,
              onPointerCancel: (e) => pointerUp(e, cancelled: true),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: double.infinity,
                  height: 192,
                  decoration: BoxDecoration(
                    color: pressed ? appAccent : soft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: appAccent.withValues(alpha: .35),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      txt(
                        '·  −',
                        size: 50,
                        color: pressed ? appAccentForeground : appAccent,
                        weight: FontWeight.w500,
                        spacing: 5,
                      ),
                      const SizedBox(height: 5),
                      txt(
                        'Tap. Hold. Connect.',
                        size: 14,
                        color: pressed ? Colors.white : ink,
                        weight: FontWeight.w600,
                      ),
                      const SizedBox(height: 9),
                      txt(
                        'Tap for a dot · Hold for a dash',
                        size: 10,
                        color: pressed ? Colors.white70 : muted,
                      ),
                      const SizedBox(height: 17),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_outlined,
                            size: 13,
                            color: pressed ? Colors.white70 : muted,
                          ),
                          const SizedBox(width: 5),
                          txt(
                            'or use your spacebar',
                            size: 9,
                            color: pressed ? Colors.white70 : muted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: action(
                  'Dot',
                  () => manual('.'),
                  icon: Icons.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: action(
                  'Dash',
                  () => manual('-'),
                  icon: Icons.remove,
                ),
              ),
              const SizedBox(width: 7),
              IconButton.filledTonal(
                tooltip: tr('Finish letter'),
                onPressed: commit,
                style: IconButton.styleFrom(
                  backgroundColor: dark ? line : bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(Icons.check, size: 19, color: ink),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: txt(
              'Pause to finish a letter. It’s that simple.',
              size: 9,
              color: muted,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: line, height: 1),
          const SizedBox(height: 11),
          feedbackRow(Icons.volume_up_outlined, 'Sound', sound, (v) {
            setState(() => sound = v);
            if (!v) stopPlayback();
            save();
          }),
          feedbackRow(
            Icons.vibration_outlined,
            'Vibration',
            vibration,
            DeviceService.supportsVibration
                ? (v) {
                    setState(() => vibration = v);
                    buzz(60);
                    save();
                  }
                : null,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
    );
  }

  Widget feedbackRow(
    IconData icon,
    String text,
    bool value,
    ValueChanged<bool>? onChanged,
  ) => SizedBox(
    height: 42,
    child: Row(
      children: [
        smallIcon(icon, size: 16),
        const SizedBox(width: 9),
        Expanded(
          child: txt(
            onChanged == null ? '$text · unavailable' : text,
            size: 11,
            color: muted,
          ),
        ),
        Transform.scale(
          scale: .7,
          alignment: Alignment.centerRight,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: appAccent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    ),
  );
  Widget messageCard() => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            txt('Your message', size: 15, weight: FontWeight.w600),
            const SizedBox(width: 10),
            Expanded(
              child: txt('${message.length} characters', size: 9, color: muted),
            ),
            IconButton(
              tooltip: tr('Delete last signal or character'),
              onPressed: () {
                commitTimer?.cancel();
                setState(() {
                  if (sequence.isNotEmpty) {
                    sequence = sequence.substring(0, sequence.length - 1);
                  } else if (message.isNotEmpty) {
                    message = message.substring(0, message.length - 1);
                    lastCode = '';
                  }
                });
                if (sequence.isNotEmpty) {
                  commitTimer = Timer(Duration(milliseconds: gap), commit);
                }
              },
              icon: smallIcon(Icons.backspace_outlined, size: 16),
            ),
            IconButton(
              tooltip: tr('Clear message'),
              onPressed: () {
                cancelInput();
                setState(() {
                  message = '';
                  lastCode = '';
                });
              },
              icon: smallIcon(Icons.delete_outline, size: 17),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: message.isEmpty
                      ? 'Your thoughts, in a different language'
                      : message,
                  style: TextStyle(
                    fontSize: message.isEmpty ? 16 : 23,
                    color: message.isEmpty ? muted : ink,
                    fontWeight: message.isEmpty
                        ? FontWeight.w400
                        : FontWeight.w500,
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(
                      text: ' ▏',
                      style: TextStyle(
                        color: appAccent,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        Divider(color: line, height: 1),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: txt(
                message.isEmpty
                    ? '· · ·   − − −   · · ·'
                    : symbols(encode(message)),
                size: 11,
                color: muted,
                spacing: 2,
              ),
            ),
            TextButton(
              onPressed: () {
                commit();
                setState(() {
                  if (message.isNotEmpty && !message.endsWith(' ')) {
                    message += ' ';
                  }
                });
              },
              child: txt('+ Add space', size: 10, color: muted),
            ),
          ],
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
  );
  Widget rhythmTip() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: soft,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: line),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.headphones_outlined, size: 20, color: appAccent),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              txt('Find your rhythm', size: 13, weight: FontWeight.w600),
              const SizedBox(height: 8),
              txt(
                'Morse is a sound, not just a code. Turn on audio and let your ears lead the way.',
                size: 11,
                color: muted,
                height: 1.8,
              ),
              const SizedBox(height: 7),
              TextButton.icon(
                onPressed: () => listen(
                  message.isEmpty
                      ? '... --- ...'
                      : encode(
                          message,
                        ).substring(0, math.min(encode(message).length, 150)),
                ),
                icon: Icon(
                  playing
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                  size: 15,
                  color: appAccent,
                ),
                label: txt(
                  playing ? 'Stop' : 'Listen to a signal',
                  size: 10,
                  color: appAccent,
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget gentleTip() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      smallIcon(Icons.favorite_border, size: 14),
      const SizedBox(width: 10),
      Expanded(
        child: txt(
          'No rush. Even the longest conversations start with a single dot.',
          size: 10,
          color: muted,
          height: 1.7,
        ),
      ),
    ],
  );
  static const lessons = [
    ('The whole alphabet', alphabet, 'Bring all 26 letters together.'),
    ('Make it count', '0123456789', 'A few numbers for your vocabulary.'),
  ];

  Map<String, String> get practiceGroups => {
    alphabet: 'Alphabet · A–Z',
    '0123456789': 'Numbers · 0–9',
    '@symbols': 'All symbols · ${morse.length}',
    '@words': 'Words · 100',
    '@sentences': 'Sentences · 100',
    '@exam': 'Exam · 20 questions',
  };

  void startSession() {
    sessionAttempts = 0;
    sessionCorrect = 0;
    sessionId = '${DateTime.now().microsecondsSinceEpoch}:${++sessionSerial}';
    _sendChoiceKey = null;
  }

  void recordPractice(PracticeMode mode, String letter, bool isCorrect) {
    sessionAttempts++;
    attempts++;
    if (isCorrect) {
      sessionCorrect++;
      correct++;
      learned.add(letter);
    }
    history.records.add(
      PracticeRecord(
        id: '$sessionId:$sessionAttempts',
        at: DateTime.now().toUtc(),
        mode: mode,
        letter: letter,
        correct: isCorrect,
        session: sessionId,
        hinted: !hideHint,
      ),
    );
  }

  void recordItemMastery(String item, bool isCorrect) {
    if (group != '@words' && group != '@sentences') return;
    final kind = group == '@words' ? 'word' : 'sentence';
    history.masteryRecords.add(
      MasteryRecord(
        id: '$sessionId:item:${history.masteryRecords.length + 1}',
        at: DateTime.now().toUtc(),
        mode: practiceMode,
        item: item,
        kind: kind,
        correct: isCorrect,
      ),
    );
  }

  void restartPractice() {
    if (examSelected) {
      startExam();
      return;
    }
    advanceTimer?.cancel();
    cancelInput();
    stopPlayback();
    setState(() {
      startSession();
      result = '';
      lastCode = '';
      target = _practiceTargets().first;
      sendIndex = 0;
    });
  }

  String _pickPracticeTarget({String? previous}) {
    final candidates = _practiceTargets()
        .where((candidate) => candidate != previous)
        .toList();
    return _weightedTarget(
      candidates.isEmpty ? _practiceTargets() : candidates,
    );
  }

  void startExam() {
    advanceTimer?.cancel();
    cancelInput();
    stopPlayback();
    final modes = <PracticeMode>[
      for (var i = 0; i < 5; i++) PracticeMode.send,
      for (var i = 0; i < 5; i++) PracticeMode.type,
      for (var i = 0; i < 5; i++) PracticeMode.choices,
      for (var i = 0; i < 5; i++) PracticeMode.sendChoices,
    ]..shuffle(math.Random());
    setState(() {
      group = '@exam';
      startSession();
      examQuestion = 1;
      examMistakes = 0;
      examStatus = '';
      examModes = modes;
      practiceMode = examModes.removeLast();
      target = _pickPracticeTarget();
      sendIndex = 0;
      result = '';
      lastCode = '';
      sequence = '';
    });
    if (practiceMode == PracticeMode.send ||
        practiceMode == PracticeMode.sendChoices) {
      focus.requestFocus();
    }
    save();
  }

  Future<void> chooseExam() async {
    final saved = _savedExam;
    final dialogContext = scaffold.currentContext;
    if (dialogContext == null) return;
    final choice = await showDialog<_ExamChoice>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: Text(tr('Exam')),
        content: Text(
          saved == null
              ? 'No unfinished exam to resume.'
              : 'Question ${saved.question} of 20 · ${saved.mistakes} ${saved.mistakes == 1 ? 'mistake' : 'mistakes'}. Starting a new exam discards it.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('resume-last-exam'),
            onPressed: saved == null
                ? null
                : () => Navigator.pop(context, _ExamChoice.resume),
            child: Text(tr('Resume last exam')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('start-new-exam'),
            onPressed: () => Navigator.pop(context, _ExamChoice.startNew),
            child: Text(tr('Start new exam')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == _ExamChoice.resume) {
      resumeExam();
    } else if (choice == _ExamChoice.startNew) {
      startExam();
    }
  }

  void resumeExam() {
    final saved = _savedExam;
    if (saved == null) return;
    advanceTimer?.cancel();
    cancelInput();
    stopPlayback();
    var question = saved.question;
    var mode = saved.mode;
    var resumedTarget = saved.target;
    final modes = List<PracticeMode>.of(saved.remainingModes);
    if (saved.pendingAdvance) {
      question++;
      mode = modes.removeLast();
      final candidates = morse.keys
          .where((character) => character != saved.target)
          .toList();
      resumedTarget = candidates[math.Random().nextInt(candidates.length)];
    }
    setState(() {
      group = '@exam';
      startSession();
      examQuestion = question;
      examMistakes = saved.mistakes;
      examStatus = '';
      examModes = modes;
      practiceMode = mode;
      target = resumedTarget;
      sendIndex = 0;
      sequence = '';
      lastCode = '';
      result = '';
    });
    if (practiceMode == PracticeMode.send ||
        practiceMode == PracticeMode.sendChoices) {
      focus.requestFocus();
    }
    save();
  }

  void _recordPracticeAnswer(
    String letter,
    bool isCorrect, {
    String? itemTarget,
    bool itemComplete = true,
  }) {
    recordPractice(practiceMode, letter, isCorrect);
    final phrase = itemTarget;
    if (phrase != null && (!isCorrect || itemComplete)) {
      recordItemMastery(phrase, isCorrect);
    }
    if (!examSelected || examStatus.isNotEmpty) return;
    result = isCorrect ? 'correct' : letter;
    if (isCorrect) {
      if (examQuestion == 20) {
        examStatus = 'passed';
        examsPassed++;
        result = 'exam-passed';
        final passedSession = sessionId;
        if (_shownPassedExamSession != passedSession) {
          _shownPassedExamSession = passedSession;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final dialogContext = scaffold.currentContext;
            if (!mounted ||
                sessionId != passedSession ||
                dialogContext == null) {
              return;
            }
            showDialog<void>(
              context: dialogContext,
              builder: (context) => AlertDialog(
                key: const ValueKey('exam-passed-dialog'),
                title: Text(tr('Exam passed!')),
                content: Text(tr('You completed all 20 questions.')),
                actions: [
                  FilledButton(
                    key: const ValueKey('exam-passed-new-exam'),
                    onPressed: () {
                      Navigator.pop(context);
                      restartPractice();
                    },
                    child: Text(tr('Start new exam')),
                  ),
                ],
              ),
            );
          });
        }
      }
    } else {
      examMistakes++;
      if (examMistakes >= 3) {
        examStatus = 'failed';
        result = 'exam-failed';
      }
    }
  }

  void changePracticeGroup(String value) {
    if (group == value) return;
    if (value == '@exam') {
      chooseExam();
      return;
    }
    setState(() {
      group = value;
      examStatus = '';
      examQuestion = 0;
      examMistakes = 0;
    });
    restartPractice();
  }

  void changePracticeMode(PracticeMode mode) {
    if (examRunning) return;
    if (mode == practiceMode) return;
    advanceTimer?.cancel();
    cancelInput();
    stopPlayback();
    setState(() {
      practiceMode = mode;
      startSession();
      result = '';
      lastCode = '';
      sendIndex = 0;
    });
    if (mode == PracticeMode.send || mode == PracticeMode.sendChoices) {
      focus.requestFocus();
    }
  }

  void openRecognition({String? characters, bool fourChoices = false}) {
    if (characters != null) group = characters;
    switchPage(2);
    changePracticeMode(fourChoices ? PracticeMode.choices : PracticeMode.type);
  }

  Widget learnPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _MorseFutureCard(onStart: () => switchPage(2)),
      const SizedBox(height: 18),
      LearnOverview(
        history: history,
        examsPassed: examsPassed,
        lessons: lessons,
        dark: dark,
        walkthroughMasteryKey: walkthroughLearnKey,
        onPractice: (mode, characters) {
          group = characters;
          target = group[0];
          switchPage(2);
          changePracticeMode(mode);
        },
      ),
    ],
  );
  Widget practicePage() =>
      practiceMode == PracticeMode.send ||
          practiceMode == PracticeMode.sendChoices
      ? PracticeWorkspace(
          walkthroughKey: walkthroughPracticeKey,
          walkthroughControlsKey: walkthroughPracticeControlsKey,
          dark: dark,
          pressed: pressed,
          holdDash: holdDash,
          playing: playing,
          hideHint: hideHint,
          fourChoices: practiceMode == PracticeMode.sendChoices,
          examMode: examSelected,
          examQuestion: examQuestion,
          examLives: 3 - examMistakes,
          examStatus: examStatus,
          choices: _sendChoiceCodes(),
          target: target,
          hintCharacter: target[sendIndex],
          path: visibleCode,
          result: result,
          group: group,
          correct: sessionCorrect,
          attempts: sessionAttempts,
          masteryCounts: _masteryDistribution,
          groups: practiceGroups,
          onGroup: changePracticeGroup,
          onHint: () {
            setState(() => hideHint = !hideHint);
            save();
          },
          onListen: () => listen(morse[target[sendIndex]]!),
          onNext: nextTarget,
          onDown: pointerDown,
          onUp: pointerUp,
          onCancel: (event) => pointerUp(event, cancelled: true),
          onDot: () => manual('.'),
          onDash: () => manual('-'),
          onCommit: commit,
          onChoice: (code) {
            if (examSelected && examStatus.isNotEmpty) return;
            if (result == 'correct') return;
            final isCorrect = code == morse[target[sendIndex]];
            setState(() {
              final expected = target[sendIndex];
              if (isCorrect && sendIndex < target.length - 1) {
                sendIndex++;
                result = 'progress';
              } else {
                _recordPracticeAnswer(
                  expected,
                  isCorrect,
                  itemTarget: target,
                  itemComplete: sendIndex == target.length - 1,
                );
                if (!examSelected) {
                  if (isCorrect) sendIndex = 0;
                  result = isCorrect ? 'correct' : symbols(code);
                }
              }
            });
            save();
            scheduleAdvance();
          },
          onMode: changePracticeMode,
          onNewSession: restartPractice,
        )
      : RecognitionWorkspace(
          groups: practiceGroups,
          initialGroup: group,
          masteryLevel: _masteryLevel,
          masteryCounts: _masteryDistribution,
          onItemAnswer: (item, isCorrect) {
            if (!mounted) return;
            setState(() => recordItemMastery(item, isCorrect));
            save();
          },
          fourChoices: practiceMode == PracticeMode.choices,
          sound: sound,
          vibration: vibration,
          dark: dark,
          hideHint: hideHint,
          examMode: examSelected,
          examQuestion: examQuestion,
          examLives: 3 - examMistakes,
          examStatus: examStatus,
          suspended: practiceSuspended || dialogOpen,
          sessionId: examSelected ? '$sessionId:$examQuestion' : sessionId,
          correct: sessionCorrect,
          attempts: sessionAttempts,
          onMode: changePracticeMode,
          onNewSession: restartPractice,
          onGroup: changePracticeGroup,
          onHint: () {
            setState(() => hideHint = !hideHint);
            save();
          },
          onAnswer: (letter, isCorrect) {
            if (!mounted) return;
            setState(() {
              _recordPracticeAnswer(letter, isCorrect);
            });
            save();
            if (examSelected && isCorrect && examRunning) scheduleAdvance();
          },
        );

  List<String> _sendChoiceCodes() {
    final targetCode = morse[target[sendIndex]]!;
    final key = '$target:$sendIndex';
    if (_sendChoiceKey != key) {
      final pool =
          morse.values.where((code) => code != targetCode).toSet().toList()
            ..shuffle(_sendChoiceRandom);
      _sendChoices = [targetCode, ...pool.take(3)]..shuffle(_sendChoiceRandom);
      _sendChoiceKey = key;
    }
    return _sendChoices;
  }

  Widget alphabetPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      intro(
        'YOUR POCKET REFERENCE',
        'A language of possibilities',
        '26 letters. 10 numbers. Just two little signals. Tap a card to listen.',
      ),
      TextField(
        onChanged: (value) =>
            setState(() => search = value.trim().toUpperCase()),
        decoration: InputDecoration(
          hintText: tr('Find a letter or number…'),
          hintStyle: TextStyle(color: muted, fontSize: 12),
          prefixIcon: Icon(Icons.search, size: 20, color: muted),
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: line),
          ),
        ),
      ),
      const SizedBox(height: 23),
      LayoutBuilder(
        builder: (context, c) {
          final entries = morse.entries
              .where(
                (e) => search.isEmpty || e.key == search || e.value == search,
              )
              .toList();
          if (entries.isEmpty) {
            return txt('No matching character. Try A–Z or 0–9.', color: muted);
          }
          final count = math.max(2, (c.maxWidth / 145).floor());
          return Wrap(
            spacing: 13,
            runSpacing: 13,
            children: entries
                .map(
                  (entry) => SizedBox(
                    width: (c.maxWidth - (count - 1) * 13) / count,
                    child: Material(
                      key: entry.key == 'A' ? walkthroughAlphabetKey : null,
                      color: selectedLetter == entry.key ? soft : surface,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        key: ValueKey('alphabet-entry-${entry.key}'),
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() => selectedLetter = entry.key);
                          listen(entry.value);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 19,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedLetter == entry.key
                                  ? appAccent
                                  : line,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  txt(
                                    entry.key,
                                    size: 32,
                                    weight: FontWeight.w500,
                                  ),
                                  const Spacer(),
                                  Icon(
                                    learned.contains(entry.key)
                                        ? Icons.check_circle_outline
                                        : Icons.volume_up_outlined,
                                    size: 15,
                                    color: learned.contains(entry.key)
                                        ? appAccent
                                        : muted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: txt(
                                  symbols(entry.value),
                                  size: 22,
                                  color: appAccent,
                                  spacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      const SizedBox(height: 23),
      gentleTip(),
    ],
  );
  Widget footer() => Row(
    children: [
      txt('morse', size: 18, weight: FontWeight.w800, color: muted),
      const SizedBox(width: 12),
      Expanded(
        child: txt(
          'LESS SCROLLING. MORE SIGNAL.',
          size: 7,
          color: muted,
          spacing: 1.5,
        ),
      ),
      smallIcon(Icons.graphic_eq, size: 14),
    ],
  );
  void howTo() {
    cancelInput();
    stopPlayback();
    dialog(
      'Small signals. Big possibilities.',
      'Meet your Morse tree.',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          txt(
            'Every letter is a little journey. Start at the top and follow your signal.',
            size: 13,
            color: muted,
            height: 1.8,
          ),
          const SizedBox(height: 23),
          howRow('·', 'Tap for a dot', 'A quick touch takes you to the left.'),
          howRow(
            '−',
            'Hold for a dash',
            'A longer touch takes you to the right.',
          ),
          howRow(
            '✓',
            'Pause to write',
            'Lift your finger and wait a moment. Your letter appears in the message.',
          ),
          const SizedBox(height: 15),
          panel(
            txt(
              'Try · − to write an A. Use the big key, dot/dash buttons, or your spacebar. You can also tap a tree letter to hear and write it. The whole tree stays visible while you send.',
              size: 12,
              color: muted,
              height: 1.8,
            ),
            color: soft,
            padding: const EdgeInsets.all(16),
          ),
        ],
      ),
    );
  }

  Widget howRow(String symbol, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: txt(
            symbol,
            size: 27,
            color: appAccent,
            weight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              txt(title, size: 14, weight: FontWeight.w600),
              const SizedBox(height: 5),
              txt(subtitle, size: 12, color: muted, height: 1.7),
            ],
          ),
        ),
      ],
    ),
  );
  void settingsDialog() {
    cancelInput();
    stopPlayback();
    final sheetContext = scaffold.currentContext;
    if (sheetContext == null) return;
    setState(() => dialogOpen = true);
    advanceTimer?.cancel();

    showModalBottomSheet<void>(
      context: sheetContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) {
          final sheetTheme = _themeFor(
            dark ? Brightness.dark : Brightness.light,
          );
          final scheme = sheetTheme.colorScheme;
          final bottomInset = MediaQuery.viewPaddingOf(sheetContext).bottom;

          Widget colorModeSelector() => SegmentedButton<ThemeMode>(
            key: const ValueKey('color-mode-selector'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Tooltip(
                  message: 'Follow device appearance',
                  child: Icon(TemplateIcons.systemAppearance),
                ),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Tooltip(
                  message: 'Use light appearance',
                  child: Icon(TemplateIcons.lightAppearance),
                ),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Tooltip(
                  message: 'Use dark appearance',
                  child: Icon(TemplateIcons.darkAppearance),
                ),
              ),
            ],
            selected: {_themeMode},
            onSelectionChanged: (selection) {
              setState(() => _themeMode = selection.first);
              updateSheet(() {});
              save();
            },
          );

          Widget section(String title, String subtitle, Widget child) =>
              Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    child,
                  ],
                ),
              );

          Widget identityRow(String label, String value) => Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );

          return Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
            child: Theme(
              data: sheetTheme,
              child: Material(
                color: scheme.surface,
                surfaceTintColor: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                    bottom: Radius.circular(28),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        (MediaQuery.sizeOf(sheetContext).height - bottomInset) *
                        .9,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 14, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Settings',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.6,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    tr('Tune the look and feel of your app.'),
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: tr('Close settings'),
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(TemplateIcons.close),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  section(
                                    'Color mode',
                                    'Follow the device or choose a theme.',
                                    colorModeSelector(),
                                  ),
                                  section(
                                    'App identity',
                                    'App details and links.',
                                    Column(
                                      children: [
                                        identityRow('Display name', 'Morse'),
                                        const SizedBox(height: 8),
                                        identityRow(
                                          'Package ID',
                                          'com.morse_code',
                                        ),
                                        const SizedBox(height: 8),
                                        identityRow(
                                          'Version',
                                          appVersion.isEmpty ? '—' : appVersion,
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                key: const ValueKey(
                                                  'privacy-policy-link',
                                                ),
                                                onPressed: DeviceService
                                                    .openPrivacyPolicy,
                                                icon: const Icon(
                                                  TemplateIcons.privacy,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Privacy policy',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              tooltip: tr(
                                                'Open-source licenses',
                                              ),
                                              onPressed: () => showLicensePage(
                                                context: sheetContext,
                                                applicationName: 'Morse',
                                                applicationVersion: appVersion,
                                                applicationLegalese:
                                                    'Material Icons by Google. CC BY 4.0: '
                                                    'https://creativecommons.org/licenses/by/4.0/',
                                              ),
                                              icon: const Icon(
                                                TemplateIcons.licenses,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  section(
                                    'Practice preferences',
                                    'Choose how Morse signals feel and sound.',
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(tr('Language')),
                                            ),
                                            DropdownButton<String>(
                                              key: const ValueKey(
                                                'language-selector',
                                              ),
                                              value: appLanguage,
                                              underline:
                                                  const SizedBox.shrink(),
                                              isDense: true,
                                              items: AppStrings.languages
                                                  .map(
                                                    (code) => DropdownMenuItem(
                                                      value: code,
                                                      child: Text(code),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (code) {
                                                if (code == null) return;
                                                setState(() {
                                                  appLanguage = code;
                                                  AppStrings.language = code;
                                                });
                                                updateSheet(() {});
                                                save();
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Input pace',
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SegmentedButton<int>(
                                          style: ButtonStyle(
                                            padding: WidgetStatePropertyAll(
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                            ),
                                          ),
                                          segments: [
                                            ButtonSegment(
                                              value: 0,
                                              label: Text(tr('Relaxed')),
                                            ),
                                            ButtonSegment(
                                              value: 1,
                                              label: Text(tr('Natural')),
                                            ),
                                            ButtonSegment(
                                              value: 2,
                                              label: Text(tr('Quick')),
                                            ),
                                          ],
                                          selected: {pace},
                                          showSelectedIcon: false,
                                          onSelectionChanged: (value) {
                                            setState(() => pace = value.first);
                                            updateSheet(() {});
                                            save();
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        feedbackRow(
                                          Icons.volume_up_outlined,
                                          'Sound',
                                          sound,
                                          (value) {
                                            setState(() => sound = value);
                                            if (!value) stopPlayback();
                                            updateSheet(() {});
                                            save();
                                          },
                                        ),
                                        feedbackRow(
                                          Icons.vibration_outlined,
                                          'Vibration',
                                          vibration,
                                          DeviceService.supportsVibration
                                              ? (value) {
                                                  setState(
                                                    () => vibration = value,
                                                  );
                                                  updateSheet(() {});
                                                  buzz(60);
                                                  save();
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                Future<void>.delayed(
                                  const Duration(milliseconds: 220),
                                  () {
                                    if (mounted) startWalkthrough();
                                  },
                                );
                              },
                              icon: const Icon(Icons.help_outline_rounded),
                              label: Text(tr('Help')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => dialogOpen = false);
      scheduleAdvance();
    });
  }

  void startWalkthrough() {
    cancelInput();
    stopPlayback();
    setState(() {
      walkthroughStep = 0;
      walkthroughTargetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateWalkthroughTarget(),
    );
  }

  void _updateWalkthroughTarget() {
    if (!mounted || walkthroughStep == null) return;
    final targetContext =
        _walkthroughStops[walkthroughStep!].target.currentContext;
    final overlayContext = scaffold.currentContext;
    if (targetContext == null || overlayContext == null) return;
    final target = targetContext.findRenderObject();
    final overlay = overlayContext.findRenderObject();
    if (target is! RenderBox || overlay is! RenderBox || !target.hasSize) {
      return;
    }
    final origin = target.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = origin & target.size;
    if (rect != walkthroughTargetRect) {
      setState(() => walkthroughTargetRect = rect);
    }
  }

  void _moveWalkthrough(int delta) {
    _walkthroughTapTimer?.cancel();
    _walkthroughTransitionPending = false;
    final next = (walkthroughStep! + delta).clamp(
      0,
      _walkthroughStops.length - 1,
    );
    _walkthroughFromTargetRect = walkthroughTargetRect;
    _walkthroughSpotlightAnimationSerial++;
    setState(() {
      walkthroughStep = next;
      page = _walkthroughStops[next].page;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateWalkthroughTarget(),
    );
  }

  void _advanceWalkthrough() {
    final step = walkthroughStep!;
    if (step == _walkthroughStops.length - 1) {
      _endWalkthrough();
      return;
    }
    if (_walkthroughStops[step].isTab) {
      _walkthroughTapTimer?.cancel();
      setState(() {
        _walkthroughTransitionPending = true;
        _walkthroughTapAnimationSerial++;
      });
      _walkthroughTapTimer = Timer(const Duration(milliseconds: 320), () {
        if (!mounted || walkthroughStep != step) return;
        final next = step + 1;
        _walkthroughFromTargetRect = walkthroughTargetRect;
        _walkthroughSpotlightAnimationSerial++;
        setState(() {
          page = _walkthroughStops[next].page;
          walkthroughStep = next;
          _walkthroughTransitionPending = false;
        });
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _updateWalkthroughTarget(),
        );
      });
      return;
    }
    _moveWalkthrough(1);
  }

  void _endWalkthrough() {
    _walkthroughTapTimer?.cancel();
    setState(() {
      walkthroughStep = null;
      _walkthroughTransitionPending = false;
    });
  }

  Widget _walkthroughOverlay() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateWalkthroughTarget(),
    );
    final step = walkthroughStep!;
    final stop = _walkthroughStops[step];
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final targetIsLow =
              walkthroughTargetRect != null &&
              walkthroughTargetRect!.center.dy > constraints.maxHeight * .58;
          return Stack(
            children: [
              if (walkthroughTargetRect == null)
                CustomPaint(
                  key: const ValueKey('walkthrough-dimmer'),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _WalkthroughDimmer(
                    target: null,
                    color: Colors.black.withValues(alpha: .68),
                  ),
                )
              else
                TweenAnimationBuilder<Rect>(
                  key: ValueKey(_walkthroughSpotlightAnimationSerial),
                  tween: _SpotlightRectTween(
                    begin: _walkthroughFromTargetRect ?? walkthroughTargetRect!,
                    end: walkthroughTargetRect!,
                  ),
                  duration: const Duration(milliseconds: 460),
                  curve: Curves.easeInOutCubic,
                  builder: (context, spotlightRect, child) => CustomPaint(
                    key: ValueKey<Rect>(spotlightRect),
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _WalkthroughDimmer(
                      target: spotlightRect,
                      color: Colors.black.withValues(alpha: .68),
                    ),
                  ),
                ),
              if (_walkthroughTransitionPending &&
                  walkthroughTargetRect != null)
                Positioned(
                  left: walkthroughTargetRect!.center.dx - 31,
                  top: walkthroughTargetRect!.center.dy - 31,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_walkthroughTapAnimationSerial),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, progress, child) => Opacity(
                        opacity: (1 - progress) * .8,
                        child: Transform.scale(
                          scale: .35 + progress * .8,
                          child: child,
                        ),
                      ),
                      child: Container(
                        key: const ValueKey('walkthrough-tab-tap-animation'),
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: appAccent, width: 3),
                          color: appAccent.withValues(alpha: .16),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 32,
                right: 12,
                child: IconButton(
                  onPressed: _endWalkthrough,
                  style: IconButton.styleFrom(
                    foregroundColor: ink,
                    backgroundColor: surface,
                    shape: const CircleBorder(),
                    minimumSize: const Size(48, 48),
                  ),
                  tooltip: tr('Skip walkthrough'),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ),
              Align(
                alignment: targetIsLow
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.fromLTRB(74, 16, 74, 18),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    padding: const EdgeInsets.fromLTRB(20, 17, 20, 18),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: soft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: txt(
                                '${step + 1} / ${_walkthroughStops.length}',
                                size: 10,
                                color: appAccent,
                                weight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: txt(
                                stop.title,
                                size: 17,
                                weight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        txt(
                          stop.description,
                          size: 13,
                          color: muted,
                          height: 1.5,
                          decoration: TextDecoration.none,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: constraints.maxHeight / 2 - 28,
                child: _walkthroughArrow(
                  Icons.arrow_back,
                  'Previous step',
                  step > 0,
                  () => _moveWalkthrough(-1),
                ),
              ),
              Positioned(
                right: 12,
                top: constraints.maxHeight / 2 - 28,
                child: _walkthroughArrow(
                  Icons.arrow_forward,
                  'Next step',
                  !_walkthroughTransitionPending,
                  _advanceWalkthrough,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _walkthroughArrow(
    IconData icon,
    String label,
    bool enabled,
    VoidCallback onPressed,
  ) => Material(
    color: enabled ? appAccent : const Color(0xFF59615E),
    shape: const CircleBorder(),
    elevation: 5,
    child: IconButton(
      tooltip: label,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      color: Colors.white,
      disabledColor: Colors.white70,
      iconSize: 22,
      constraints: const BoxConstraints.tightFor(width: 56, height: 56),
    ),
  );

  void dialog(
    String eyebrow,
    String title,
    Widget content, {
    void Function(BuildContext context)? onHelp,
    void Function(VoidCallback refresh)? onRefresh,
  }) {
    final context = scaffold.currentContext;
    if (context == null) return;
    setState(() => dialogOpen = true);
    advanceTimer?.cancel();
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateRoute) {
          onRefresh?.call(() => updateRoute(() {}));
          return Dialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: txt(
                            eyebrow.toUpperCase(),
                            size: 8,
                            color: muted,
                            spacing: 1.4,
                          ),
                        ),
                        IconButton(
                          tooltip: tr('Close'),
                          onPressed: () => Navigator.pop(context),
                          icon: smallIcon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    txt(title, size: 27, weight: FontWeight.w600, height: 1.2),
                    const SizedBox(height: 17),
                    content,
                    const SizedBox(height: 23),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onHelp != null) ...[
                          TextButton.icon(
                            onPressed: () => onHelp(context),
                            icon: const Icon(Icons.help_outline, size: 17),
                            label: Text(tr('Help')),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(64, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        action(
                          tr('Got it'),
                          () => Navigator.pop(context),
                          icon: Icons.check,
                          primary: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => dialogOpen = false);
      scheduleAdvance();
    });
  }
}

class _WalkthroughStop {
  const _WalkthroughStop({
    required this.page,
    required this.target,
    this.isTab = false,
    required this.title,
    required this.description,
  });

  final int page;
  final GlobalKey target;
  final bool isTab;
  final String title;
  final String description;
}

class _SpotlightRectTween extends Tween<Rect> {
  _SpotlightRectTween({required Rect begin, required Rect end})
    : super(begin: begin, end: end);

  @override
  Rect lerp(double t) => Rect.lerp(begin!, end!, t)!;
}

class _WalkthroughDimmer extends CustomPainter {
  const _WalkthroughDimmer({required this.target, required this.color});
  final Rect? target;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (target != null) {
      path.addRRect(
        RRect.fromRectAndRadius(target!.inflate(4), const Radius.circular(12)),
      );
      path.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WalkthroughDimmer oldDelegate) =>
      oldDelegate.target != target || oldDelegate.color != color;
}

class _MorseFutureCard extends StatelessWidget {
  const _MorseFutureCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = scheme.surfaceContainerLow;
    final glow = Color.lerp(base, scheme.primary, 0.2)!;
    final orbit = Color.lerp(base, scheme.tertiary, 0.14)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [glow, base, orbit],
            stops: const [0, 0.58, 1],
          ),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.32)),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -44,
              top: -55,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: -13,
              top: -24,
              child: Container(
                width: 136,
                height: 136,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.tertiary.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      tr('MORSE'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    tr('One signal at a time.'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.65,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    tr('Build Morse recognition at a steady, comfortable pace.'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                    label: Text(tr('Start a practice')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
