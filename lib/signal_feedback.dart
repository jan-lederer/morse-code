import 'dart:async';
import 'dart:collection';

/// One input signal; it may be released before its queued audio starts.
class SignalTone {
  SignalTone._();
  bool _released = false, _dash = false;
}

/// Keeps rapid input audible as separate signals without delaying input itself.
class SignalFeedback {
  SignalFeedback(this._tone);

  final void Function(bool) _tone;
  final _pending = Queue<SignalTone>();
  SignalTone? _active;
  Timer? _dotTimer, _dashTimer, _gapTimer;
  bool _dotElapsed = false, _dashElapsed = false;

  SignalTone press() {
    final signal = SignalTone._();
    _pending.add(signal);
    _next();
    return signal;
  }

  void release(SignalTone signal, {required bool dash}) {
    signal
      .._released = true
      .._dash = dash;
    _finishIfReady();
  }

  void _next() {
    if (_active != null || _gapTimer != null || _pending.isEmpty) return;
    _active = _pending.removeFirst();
    _dotElapsed = _dashElapsed = false;
    _tone(true);
    _dotTimer = Timer(const Duration(milliseconds: 100), () {
      _dotElapsed = true;
      _finishIfReady();
    });
    _dashTimer = Timer(const Duration(milliseconds: 300), () {
      _dashElapsed = true;
      _finishIfReady();
    });
  }

  void _finishIfReady() {
    final signal = _active;
    if (signal == null || !signal._released) return;
    if (!(signal._dash ? _dashElapsed : _dotElapsed)) return;
    _dotTimer?.cancel();
    _dashTimer?.cancel();
    _active = null;
    _tone(false);
    // Always reserve silence, including when the next press arrives later.
    _gapTimer = Timer(const Duration(milliseconds: 100), () {
      _gapTimer = null;
      _next();
    });
  }

  void cancel() {
    _dotTimer?.cancel();
    _dashTimer?.cancel();
    _gapTimer?.cancel();
    _gapTimer = null;
    _active = null;
    _pending.clear();
    _tone(false);
  }
}
