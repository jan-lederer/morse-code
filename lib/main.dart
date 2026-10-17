import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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

const coral = Color(0xFFE77860);
const green = Color(0xFF648D78);
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DitApp());
}

class DitApp extends StatefulWidget {
  const DitApp({super.key});
  @override
  State<DitApp> createState() => _DitAppState();
}

class _DitAppState extends State<DitApp> with WidgetsBindingObserver {
  bool dark = false,
      sound = true,
      vibration = false,
      numbers = false,
      pressed = false,
      playing = false;
  int page = 1, pace = 1, attempts = 0, correct = 0;
  final learned = <String>{};
  ProgressHistory history = ProgressHistory();
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
  PracticeMode practiceMode = PracticeMode.send;
  String appVersion = '';
  Timer? commitTimer, holdTimer, advanceTimer;
  final signalFeedback = SignalFeedback(DeviceService.tone);
  SignalTone? inputTone;
  bool practiceSuspended = false, dialogOpen = false;
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
  Color get bg => dark ? const Color(0xFF171C1D) : const Color(0xFFF6F5F1);
  Color get surface => dark ? const Color(0xFF202627) : Colors.white;
  Color get ink => dark ? const Color(0xFFF0F1EC) : const Color(0xFF26302F);
  Color get muted => dark ? const Color(0xFF9AA4A0) : const Color(0xFF8A918B);
  Color get line => dark ? const Color(0xFF353D3B) : const Color(0xFFEBEBE4);
  Color get soft => dark ? const Color(0xFF322B28) : const Color(0xFFFFF1EB);
  int get threshold => [320, 230, 170][pace];
  int get gap => [1400, 1000, 700][pace];
  @override
  void initState() {
    super.initState();
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
      setState(() {
        dark = data['dark'] == true;
        sound = data['sound'] != false;
        vibration = data['vibration'] == true;
        hideHint = data['hideHint'] == true;
        pace = (data['pace'] is int ? data['pace'] as int : 1).clamp(0, 2);
        final loaded = ProgressHistory.fromSaved(data);
        loaded.merge(history.records);
        history = loaded;
        attempts = history.totalAttempts;
        correct = history.totalCorrect;
        learned
          ..clear()
          ..addAll(history.allLetters);
      });
    } catch (_) {
      /* A damaged preference never prevents startup. */
    }
  }

  void save() {
    DeviceService.save(
      jsonEncode({
        'dark': dark,
        'sound': sound,
        'vibration': vibration,
        'hideHint': hideHint,
        'pace': pace,
        'attempts': attempts,
        'correct': correct,
        'learned': learned.toList(),
        'progress': history.toJson(),
      }),
    );
  }

  @override
  void dispose() {
    commitTimer?.cancel();
    holdTimer?.cancel();
    advanceTimer?.cancel();
    playbackId++;
    DeviceService.stopPattern();
    signalFeedback.cancel();
    WidgetsBinding.instance.removeObserver(this);
    focus.dispose();
    super.dispose();
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
        content: Text(text),
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
      sound = true;
    });
    save();
    final lead = await DeviceService.playPattern(
      code,
      sound: true,
      vibration: false,
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
          recordPractice(practiceMode, expected, isCorrect);
          if (isCorrect) {
            sendIndex = 0;
            result = 'correct';
            buzz(65);
          } else {
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
    if (page != 2 ||
        (practiceMode != PracticeMode.send &&
            practiceMode != PracticeMode.sendChoices) ||
        result != 'correct' ||
        practiceSuspended ||
        dialogOpen) {
      return;
    }
    advanceTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted &&
          page == 2 &&
          result == 'correct' &&
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
    final candidates = _practiceTargets().where((c) => c != target).toList();
    setState(() {
      target = candidates.isEmpty
          ? _practiceTargets().first
          : candidates[math.Random().nextInt(candidates.length)];
      sendIndex = 0;
      result = '';
      lastCode = '';
    });
  }

  List<String> _practiceTargets() => group == '@words'
      ? practiceWords
      : group == '@sentences'
      ? practiceSentences
      : group.split('');

  Text txt(
    String text, {
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? spacing,
    TextAlign? align,
  }) => Text(
    text,
    textAlign: align,
    style: TextStyle(
      fontSize: size,
      color: color ?? ink,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
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
      borderRadius: BorderRadius.circular(18),
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
      color: accent ? coral : muted,
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
    bool compact = false,
  }) => FilledButton.icon(
    onPressed: onTap,
    icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 17),
    label: Text(text),
    style: FilledButton.styleFrom(
      backgroundColor: primary ? coral : (dark ? line : bg),
      foregroundColor: primary ? Colors.white : ink,
      elevation: 0,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 19,
        vertical: 17,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
  Widget logo({bool light = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: coral,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 13,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white,
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
          text: 'dit',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -2,
            color: light ? Colors.white : ink,
          ),
          children: const [
            TextSpan(
              text: '.',
              style: TextStyle(color: coral),
            ),
          ],
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: coral,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      fontFamily: 'Roboto',
    );
    return MaterialApp(
      title: 'dit. — Learn Morse',
      debugShowCheckedModeBanner: false,
      theme: theme,
      scaffoldMessengerKey: messenger,
      home: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1050;
          final shortInput =
              (page == 1 || page == 2) && !wide && constraints.maxHeight < 450;
          return Scaffold(
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
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        label: 'Learn',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_tree_outlined),
                        label: 'Morse tree',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bolt_outlined),
                        label: 'Practice',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.grid_view_rounded),
                        label: 'Alphabet',
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget sidebar() => Container(
    width: 230,
    color: const Color(0xFF252F2E),
    padding: const EdgeInsets.fromLTRB(22, 32, 22, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        logo(light: true),
        const SizedBox(height: 10),
        txt(
          'A LITTLE SIGNAL GOES A LONG WAY',
          size: 7,
          color: const Color(0xFF9CA7A0),
          spacing: 1.4,
        ),
        const SizedBox(height: 55),
        txt(
          'YOUR WORKSPACE',
          size: 9,
          color: const Color(0xFF89958F),
          weight: FontWeight.w600,
          spacing: 1.6,
        ),
        const SizedBox(height: 16),
        ...List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Material(
              color: page == i ? const Color(0xFF3B4541) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => switchPage(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        [
                          Icons.menu_book_outlined,
                          Icons.account_tree_outlined,
                          Icons.bolt_outlined,
                          Icons.grid_view_rounded,
                        ][i],
                        size: 19,
                        color: page == i
                            ? const Color(0xFFF1C5AC)
                            : const Color(0xFF9AA6A0),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: txt(
                          ['Learn', 'Morse tree', 'Practice', 'Alphabet'][i],
                          size: 13,
                          color: page == i
                              ? Colors.white
                              : const Color(0xFFA5AFA9),
                          weight: page == i ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (page == i)
                        const Icon(Icons.circle, size: 5, color: coral),
                    ],
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
            color: const Color(0xFF303B37),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF414D43)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              txt(
                '· − ·',
                size: 30,
                color: const Color(0xFFD4B78C),
                spacing: 4,
              ),
              const SizedBox(height: 9),
              txt(
                'A little, every day.',
                size: 14,
                color: const Color(0xFFF0EEE6),
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 8),
              txt(
                'Great things start with\nthe smallest signals.',
                size: 11,
                color: const Color(0xFFA3AEA3),
                height: 1.7,
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => switchPage(2),
                child: Row(
                  children: [
                    Expanded(
                      child: txt(
                        'Keep the rhythm',
                        size: 10,
                        color: const Color(0xFFDCBEA0),
                        weight: FontWeight.w600,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      size: 15,
                      color: Color(0xFFDCBEA0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => settingsDialog(),
          icon: const Icon(Icons.tune, size: 18, color: Color(0xFFA3AEA3)),
          label: txt('Settings', size: 12, color: const Color(0xFFA3AEA3)),
        ),
        const SizedBox(height: 18),
        txt(
          '●  Your own pace. Your own signal.',
          size: 8,
          color: const Color(0xFF7D8B82),
        ),
      ],
    ),
  );
  Widget topbar(bool wide, {bool compact = false}) => Container(
    height: compact
        ? 48
        : wide
        ? 76
        : 65,
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
        ] else if (compact)
          SizedBox(height: 30, child: FittedBox(child: logo()))
        else
          logo(),
        const Spacer(),
        if (wide) ...[
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          txt('Made for your own pace', size: 10, color: muted),
          const SizedBox(width: 20),
        ],
        IconButton(
          tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () {
            setState(() => dark = !dark);
            save();
          },
          icon: smallIcon(
            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        ),
        if (!wide)
          IconButton(
            tooltip: 'Settings',
            onPressed: settingsDialog,
            icon: smallIcon(Icons.tune),
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: coral,
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
                    text: title,
                    style: TextStyle(
                      fontSize: c.maxWidth < 600 ? 32 : 40,
                      height: 1.17,
                      letterSpacing: -1.5,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                    children: const [
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: coral),
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
          compact: true,
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
  Widget treeCard() => panel(
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
              message: 'Show numbers',
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
                        activeTrackColor: coral,
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
                Container(width: 14, height: 2, color: coral),
                const SizedBox(width: 6),
                txt('Your signal’s path', size: 9, color: muted),
              ],
            ),
          ],
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 17),
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
              color: dark ? bg : const Color(0xFFF7F7F2),
              borderRadius: BorderRadius.circular(10),
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
                        color: code.isEmpty ? muted : coral,
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
                    color: pressed ? coral : green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Semantics(
            label: 'Morse key. Tap for dot. Hold for dash.',
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
                    color: pressed ? coral : soft,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: coral.withValues(alpha: .35),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      txt(
                        '·  −',
                        size: 50,
                        color: pressed ? Colors.white : coral,
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
                  compact: true,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: action(
                  'Dash',
                  () => manual('-'),
                  icon: Icons.remove,
                  compact: true,
                ),
              ),
              const SizedBox(width: 7),
              IconButton.filledTonal(
                tooltip: 'Finish letter',
                onPressed: commit,
                style: IconButton.styleFrom(
                  backgroundColor: dark ? line : bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
            activeTrackColor: coral,
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
              tooltip: 'Delete last signal or character',
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
              tooltip: 'Clear message',
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
                        color: coral,
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
      color: dark ? const Color(0xFF29302B) : const Color(0xFFEDEEE5),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.headphones_outlined, size: 20, color: green),
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
                  color: green,
                ),
                label: txt(
                  playing ? 'Stop' : 'Listen to a signal',
                  size: 10,
                  color: green,
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
    ('Your first signals', 'ET', 'Two signals. A whole new language.'),
    ('Build a rhythm', 'IANM', 'Connect two signals into something new.'),
    (
      'A little more conversation',
      'SURWDKGO',
      'Follow the branches. Find your flow.',
    ),
    ('The whole alphabet', 'HVFLPJBXCYZQ', 'Bring all 26 letters together.'),
    ('Make it count', '0123456789', 'A few numbers for your vocabulary.'),
  ];

  void startSession() {
    sessionAttempts = 0;
    sessionCorrect = 0;
    sessionId = '${DateTime.now().microsecondsSinceEpoch}:${++sessionSerial}';
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

  void restartPractice() {
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

  void changePracticeGroup(String value) {
    if (group == value) return;
    group = value;
    restartPractice();
  }

  void changePracticeMode(PracticeMode mode) {
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

  Widget learnPage() => LearnOverview(
    history: history,
    lessons: lessons,
    dark: dark,
    onPractice: (mode, characters) {
      group = characters;
      target = group[0];
      switchPage(2);
      changePracticeMode(mode);
    },
  );
  Widget practicePage() =>
      practiceMode == PracticeMode.send ||
          practiceMode == PracticeMode.sendChoices
      ? PracticeWorkspace(
          dark: dark,
          pressed: pressed,
          holdDash: holdDash,
          playing: playing,
          hideHint: hideHint,
          fourChoices: practiceMode == PracticeMode.sendChoices,
          choices: _sendChoiceCodes(),
          target: target,
          hintCharacter: target[sendIndex],
          path: visibleCode,
          result: result,
          group: group,
          correct: sessionCorrect,
          attempts: sessionAttempts,
          groups: {
            alphabet: 'All letters',
            for (final lesson in lessons) lesson.$2: lesson.$1,
            '@words': 'Real words',
            '@sentences': 'Sentences',
          },
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
            if (result == 'correct') return;
            final isCorrect = code == morse[target[sendIndex]];
            setState(() {
              final expected = target[sendIndex];
              if (isCorrect && sendIndex < target.length - 1) {
                sendIndex++;
                result = 'progress';
              } else {
                recordPractice(practiceMode, expected, isCorrect);
                if (isCorrect) sendIndex = 0;
                result = isCorrect ? 'correct' : symbols(code);
              }
            });
            save();
            scheduleAdvance();
          },
          onMode: changePracticeMode,
          onNewSession: restartPractice,
        )
      : RecognitionWorkspace(
          groups: {
            alphabet: 'All letters',
            for (final lesson in lessons) lesson.$2: lesson.$1,
            '@words': 'Real words',
            '@sentences': 'Sentences',
          },
          initialGroup: group,
          fourChoices: practiceMode == PracticeMode.choices,
          sound: sound,
          vibration: vibration,
          dark: dark,
          hideHint: hideHint,
          suspended: practiceSuspended || dialogOpen,
          sessionId: sessionId,
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
              recordPractice(practiceMode, letter, isCorrect);
            });
            save();
          },
        );

  List<String> _sendChoiceCodes() {
    final targetCode = morse[target[sendIndex]]!;
    final pool = morse.values
        .where((code) => code != targetCode)
        .toSet()
        .toList();
    return [targetCode, ...pool.take(3)];
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
          hintText: 'Find a letter or number…',
          hintStyle: TextStyle(color: muted, fontSize: 12),
          prefixIcon: Icon(Icons.search, size: 20, color: muted),
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
                      color: selectedLetter == entry.key ? soft : surface,
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () {
                          setState(() => selectedLetter = entry.key);
                          buzz(25);
                          listen(entry.value);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 19,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedLetter == entry.key ? coral : line,
                            ),
                            borderRadius: BorderRadius.circular(13),
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
                                        ? green
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
                                  color: coral,
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
      txt('dit.', size: 18, weight: FontWeight.w800, color: muted),
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
          child: txt(symbol, size: 27, color: coral, weight: FontWeight.w600),
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
    dialog(
      'MAKE IT YOURS',
      'Your rhythm, your rules.',
      StatefulBuilder(
        builder: (context, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            txt(
              'Little adjustments for a more comfortable practice.',
              size: 13,
              color: muted,
              height: 1.7,
            ),
            const SizedBox(height: 8),
            Text(
              appVersion.isEmpty ? 'Version …' : 'Version $appVersion',
              key: const ValueKey('app-version'),
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 20),
            feedbackRow(Icons.volume_up_outlined, 'Sound', sound, (v) {
              setState(() => sound = v);
              if (!v) stopPlayback();
              update(() {});
              save();
            }),
            feedbackRow(
              Icons.vibration_outlined,
              'Vibration',
              vibration,
              DeviceService.supportsVibration
                  ? (v) {
                      setState(() => vibration = v);
                      update(() {});
                      buzz(60);
                      save();
                    }
                  : null,
            ),
            feedbackRow(Icons.dark_mode_outlined, 'Dark mode', dark, (v) {
              setState(() => dark = v);
              update(() {});
              save();
            }),
            const SizedBox(height: 20),
            txt('INPUT PACE', size: 9, color: muted, spacing: 1.5),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Relaxed')),
                ButtonSegment(value: 1, label: Text('Natural')),
                ButtonSegment(value: 2, label: Text('Quick')),
              ],
              selected: {pace},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                textStyle: const TextStyle(fontSize: 11),
                selectedBackgroundColor: soft,
                selectedForegroundColor: coral,
              ),
              onSelectionChanged: (v) {
                setState(() => pace = v.first);
                update(() {});
                save();
              },
            ),
            const SizedBox(height: 18),
            txt(
              'Relaxed gives you more time between signals. Settings and practice progress stay on this device.',
              size: 11,
              color: muted,
              height: 1.8,
            ),
            if (!DeviceService.supportsVibration) ...[
              const SizedBox(height: 12),
              txt(
                'Vibration is unavailable in this browser. Use the Android app or a supported browser.',
                size: 11,
                color: muted,
                height: 1.8,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void dialog(String eyebrow, String title, Widget content) {
    final context = scaffold.currentContext;
    if (context == null) return;
    setState(() => dialogOpen = true);
    advanceTimer?.cancel();
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      tooltip: 'Close',
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
                Align(
                  alignment: Alignment.centerRight,
                  child: action(
                    'Got it',
                    () => Navigator.pop(context),
                    icon: Icons.check,
                    primary: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => dialogOpen = false);
      scheduleAdvance();
    });
  }
}
