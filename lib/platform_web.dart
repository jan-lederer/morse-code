import 'dart:js_interop';

@JS('ditLoad')
external JSString? _load();
@JS('ditVersion')
external JSPromise<JSString> _version();
@JS('ditSave')
external void _save(JSString value);
@JS('ditTone')
external void _tone(JSBoolean enabled);
@JS('ditVibrate')
external void _vibrate(JSNumber duration);
@JS('ditCancelVibration')
external void _cancelVibration();
@JS('ditPlayPattern')
external JSPromise<JSNumber> _playPattern(
  JSString code,
  JSBoolean sound,
  JSBoolean vibration,
);
@JS('ditStopPattern')
external void _stopPattern();
@JS('ditCanVibrate')
external JSBoolean _canVibrate();

class DeviceService {
  static Future<String?> version() async {
    try {
      final value = (await _version().toDart).toDart;
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> load() async => _load()?.toDart;
  static Future<int> playPattern(
    String code, {
    required bool sound,
    required bool vibration,
  }) async {
    try {
      return (await _playPattern(
        code.toJS,
        sound.toJS,
        vibration.toJS,
      ).toDart).toDartInt;
    } catch (_) {
      return -1;
    }
  }

  static void stopPattern() => _stopPattern();
  static Future<void> save(String value) async => _save(value.toJS);
  static void tone(bool enabled) => _tone(enabled.toJS);
  static void vibrate(int duration) => _vibrate(duration.toJS);
  static void cancelVibration() => _cancelVibration();
  static bool get supportsVibration => _canVibrate().toDart;
}
