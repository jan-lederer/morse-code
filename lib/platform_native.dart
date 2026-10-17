import 'package:flutter/services.dart';

class DeviceService {
  static const _channel = MethodChannel('studio.dit/device');
  static Future<String?> load() async {
    try {
      return await _channel.invokeMethod<String>('load');
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String value) async {
    try {
      await _channel.invokeMethod('save', value);
    } catch (_) {}
  }

  static void tone(bool enabled) {
    _channel.invokeMethod<void>('tone', enabled).catchError((_) {});
  }

  static void vibrate(int duration) {
    _channel.invokeMethod<void>('vibrate', duration).catchError((_) {});
  }

  static bool get supportsVibration => true;
}
