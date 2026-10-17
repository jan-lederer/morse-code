import 'dart:js_interop';

@JS('ditLoad')
external JSString? _load();
@JS('ditSave')
external void _save(JSString value);
@JS('ditTone')
external void _tone(JSBoolean enabled);
@JS('ditVibrate')
external void _vibrate(JSNumber duration);
@JS('ditCanVibrate')
external JSBoolean _canVibrate();

class DeviceService {
  static Future<String?> load() async => _load()?.toDart;
  static Future<void> save(String value) async => _save(value.toJS);
  static void tone(bool enabled) => _tone(enabled.toJS);
  static void vibrate(int duration) => _vibrate(duration.toJS);
  static bool get supportsVibration => _canVibrate().toDart;
}
