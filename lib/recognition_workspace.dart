import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'morse.dart';
import 'practice_controls.dart';
import 'platform_service.dart';

class RecognitionWorkspace extends StatefulWidget {
  const RecognitionWorkspace({
    super.key,
    required this.groups,
    required this.initialGroup,
    required this.sound,
    required this.vibration,
    required this.onAnswer,
    this.fourChoices = false,
    this.hideHint = false,
    this.suspended = false,
    this.dark = false,
    this.onHint,
    this.onMode,
    this.onGroup,
    this.correct,
    this.attempts,
    this.sessionId = '',
    this.onNewSession,
  });

  final Map<String, String> groups;
  final String initialGroup;
  final bool sound, vibration, fourChoices, hideHint, suspended, dark;
  final VoidCallback? onHint;
  final ValueChanged<PracticeMode>? onMode;
  final ValueChanged<String>? onGroup;
  final int? correct, attempts;
  final String sessionId;
  final VoidCallback? onNewSession;
  final void Function(String letter, bool correct) onAnswer;

  @override
  State<RecognitionWorkspace> createState() => _RecognitionWorkspaceState();
}

class _RecognitionWorkspaceState extends State<RecognitionWorkspace>
    with WidgetsBindingObserver {
  final _random = Random();
  final _answer = TextEditingController();
  final _answerFocus = FocusNode();
  final _answersKey = GlobalKey();
  Timer? _advanceTimer;
  late String _group, _target;
  late bool _sound, _vibration, _fourChoices;
  bool _playing = false, _correct = false, _lifecycleSuspended = false;
  late bool _hideHint;
  bool get _suspended => widget.suspended || _lifecycleSuspended;
  List<String> _choices = [];
  final _wrongChoices = <String>{};
  int _playback = 0, _signalIndex = -1, _attempts = 0, _successes = 0;
  String _feedback = '';
  static const _accent = Color(0xFFE77860);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _group = widget.initialGroup;
    _sound = widget.sound;
    _vibration = widget.vibration && DeviceService.supportsVibration;
    _fourChoices = widget.fourChoices;
    _hideHint = widget.hideHint;
    _pickQuestion();
  }

  void _pickQuestion({String? previous}) {
    _advanceTimer?.cancel();
    final candidates = _group.split('').where((c) => c != previous).toList();
    _target = candidates.isEmpty
        ? _group[0]
        : candidates[_random.nextInt(candidates.length)];
    // Small lessons still need four distinct options. Prefer the lesson's
    // characters, then fill from the same kind of characters (letters/numbers).
    final pool =
        (_group.contains(RegExp('[0-9]')) ? '0123456789' : alphabet)
            .split('')
            .where((c) => c != _target && !_group.contains(c))
            .toList()
          ..shuffle(_random);
    final distractors = _group.split('').where((c) => c != _target).toList()
      ..shuffle(_random);
    _choices = [
      _target,
      ...[...distractors, ...pool].take(3),
    ]..shuffle(_random);
    _correct = false;
    _wrongChoices.clear();
    _feedback = '';
    _answer.clear();
  }

  void _stop() {
    _playback++;
    DeviceService.stopPattern();
    DeviceService.tone(false);
    DeviceService.cancelVibration();
    _playing = false;
    _signalIndex = -1;
  }

  Future<void> _play() async {
    if (_suspended) return;
    if (_playing) {
      setState(_stop);
      return;
    }
    _stop();
    final id = _playback;
    final code = morse[_target]!;
    setState(() => _playing = true);
    final lead = await DeviceService.playPattern(
      code,
      sound: _sound,
      vibration: _vibration,
    );
    if (!mounted || id != _playback) return;
    if (lead < 0) {
      setState(_stop);
      return;
    }
    if (lead > 0) await Future<void>.delayed(Duration(milliseconds: lead));
    for (var i = 0; i < code.length; i++) {
      if (!mounted || id != _playback) return;
      final duration = code[i] == '.' ? 100 : 300;
      setState(() => _signalIndex = i);
      await Future<void>.delayed(Duration(milliseconds: duration));
      if (!mounted || id != _playback) return;
      setState(() => _signalIndex = -1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (mounted && id == _playback) setState(() => _playing = false);
  }

  void _next() {
    if (_suspended) return;
    setState(() {
      _stop();
      _pickQuestion(previous: _target);
    });
    _play();
  }

  void _submit(String raw) {
    if (_correct || _suspended) return;
    final value = raw.trim().toUpperCase();
    if (value.length != 1 || !morse.containsKey(value)) {
      setState(() => _feedback = 'Enter one letter or number.');
      return;
    }
    final correct = value == _target;
    setState(() {
      _stop();
      _attempts++;
      _correct = correct;
      if (correct) {
        _successes++;
        _feedback = 'Correct! It’s $_target. Next letter…';
      } else {
        _wrongChoices.add(value);
        _answer.clear();
        _feedback = 'Not quite. Replay the signal and try again.';
      }
    });
    widget.onAnswer(_target, correct);
    _scheduleAdvance();
  }

  void _scheduleAdvance() {
    _advanceTimer?.cancel();
    if (!_correct || _suspended) return;
    _advanceTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted && !_suspended && _correct) _next();
    });
  }

  void _setMode(PracticeMode mode) {
    if (widget.onMode != null) {
      widget.onMode!(mode);
      return;
    }
    if (mode == PracticeMode.send) return;
    setState(() {
      _stop();
      _fourChoices = mode == PracticeMode.choices;
      _pickQuestion(previous: _target);
    });
  }

  void _setGroup(String group) {
    if (widget.onGroup != null) {
      widget.onGroup!(group);
      return;
    }
    setState(() {
      _stop();
      _group = group;
      _pickQuestion();
    });
  }

  @override
  void didUpdateWidget(covariant RecognitionWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialGroup != widget.initialGroup ||
        oldWidget.fourChoices != widget.fourChoices ||
        oldWidget.sessionId != widget.sessionId) {
      _stop();
      _group = widget.initialGroup;
      _fourChoices = widget.fourChoices;
      _pickQuestion(previous: _target);
    }
    if (oldWidget.sound != widget.sound ||
        oldWidget.vibration != widget.vibration ||
        oldWidget.hideHint != widget.hideHint ||
        oldWidget.suspended != widget.suspended) {
      _stop();
      _sound = widget.sound;
      _vibration = widget.vibration && DeviceService.supportsVibration;
      _hideHint = widget.hideHint;
      _scheduleAdvance();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleSuspended = state != AppLifecycleState.resumed;
    if (_suspended) setState(_stop);
    _scheduleAdvance();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _stop();
    _answerFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _answer.dispose();
    super.dispose();
  }

  Color get _muted =>
      widget.dark ? const Color(0xFF9AA4A0) : const Color(0xFF747E77);
  Color get _surface => widget.dark ? const Color(0xFF202627) : Colors.white;
  Color get _line =>
      widget.dark ? const Color(0xFF353D3B) : const Color(0xFFE4E7DC);

  Widget _challenge() => Container(
    key: const ValueKey('recognition-signal'),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(
          'NAME THIS CHARACTER',
          style: TextStyle(fontSize: 9, color: _muted),
        ),
        Expanded(
          child: Center(
            child: _hideHint
                ? Text(
                    _sound || _vibration
                        ? 'Listen or feel the signal'
                        : 'Show the hint or enable sound in Settings',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12),
                  )
                : FittedBox(
                    child: Text(
                      symbols(morse[_target]!),
                      key: const ValueKey('recognition-code'),
                      style: TextStyle(fontSize: 56, color: _accent),
                    ),
                  ),
          ),
        ),
        if (!_hideHint)
          Container(
            key: const ValueKey('recognition-light'),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _signalIndex < 0 ? _line : _accent,
            ),
          ),
        PracticeSignalActions(
          playing: _playing,
          hideHint: _hideHint,
          onListen: _play,
          onHint: widget.onHint ?? () => setState(() => _hideHint = !_hideHint),
        ),
        SizedBox(
          height: 28,
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Text(
                _feedback,
                key: const ValueKey('recognition-feedback'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: _correct ? const Color(0xFF648D78) : _muted,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // Keep EditableText's connection alive when keyboard insets change the layout.
  Widget _answers() => KeyedSubtree(key: _answersKey, child: _buildAnswers());

  Widget _buildAnswers() {
    if (_fourChoices) {
      return Column(
        key: const ValueKey('recognition-grid'),
        children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < 2; col++) ...[
                    if (col > 0) const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox.expand(
                        child: OutlinedButton(
                          key: ValueKey(
                            'recognition-choice-${_choices[row * 2 + col]}',
                          ),
                          onPressed:
                              _correct ||
                                  _wrongChoices.contains(
                                    _choices[row * 2 + col],
                                  )
                              ? null
                              : () => _submit(_choices[row * 2 + col]),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: widget.dark
                                ? const Color(0xFF322B28)
                                : const Color(0xFFFFF1EB),
                            foregroundColor: _accent,
                            side: BorderSide(
                              color: _accent.withValues(alpha: .5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _choices[row * 2 + col],
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('recognition-answer'),
            controller: _answer,
            focusNode: _answerFocus,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(1),
            ],
            decoration: InputDecoration(
              labelText: 'Your answer',
              hintText: 'A–Z or 0–9',
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            // The default completion action unfocuses the field and closes the keyboard.
            onEditingComplete: () {},
            onSubmitted: _submit,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _correct ? null : () => _submit(_answer.text),
          child: const Text('Check'),
        ),
      ],
    );
  }

  Widget _stats() => SizedBox(
    height: 34,
    child: Row(
      children: [
        Expanded(
          child: PracticeStats(
            correct: widget.correct ?? _successes,
            attempts: widget.attempts ?? _attempts,
          ),
        ),
        IconButton(
          tooltip: 'Skip letter',
          onPressed: _next,
          icon: Icon(Icons.skip_next_outlined, color: _muted),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final header = PracticeHeader(
              mode: _fourChoices ? PracticeMode.choices : PracticeMode.type,
              group: _group,
              groups: widget.groups,
              onMode: _setMode,
              onGroup: _setGroup,
              onNewSession:
                  widget.onNewSession ??
                  () => setState(() {
                    _stop();
                    _attempts = 0;
                    _successes = 0;
                    _pickQuestion(previous: _target);
                  }),
            );
            if (bounds.maxHeight < 440) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    header,
                    const SizedBox(height: 8),
                    SizedBox(height: 170, child: _challenge()),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: _fourChoices ? 176 : 64,
                      child: _answers(),
                    ),
                    const SizedBox(height: 6),
                    _stats(),
                  ],
                ),
              );
            }
            return Column(
              children: [
                header,
                const SizedBox(height: 8),
                Expanded(flex: 3, child: _challenge()),
                const SizedBox(height: 10),
                if (_fourChoices)
                  Expanded(flex: 2, child: _answers())
                else
                  SizedBox(height: 64, child: _answers()),
                const SizedBox(height: 6),
                _stats(),
              ],
            );
          },
        ),
      ),
    ),
  );
}
