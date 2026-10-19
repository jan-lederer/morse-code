import 'package:flutter/services.dart';

class DeviceService {
  static const _channel = MethodChannel('studio.dit/device');
  static Future<String?> version() async {
    try {
      return await _channel.invokeMethod<String>('version');
    } catch (_) {
      return null;
    }
  }

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

  static Future<void> openPrivacyPolicy() async {
    try {
      await _channel.invokeMethod<void>('openPrivacyPolicy');
    } catch (_) {}
  }

  static void tone(bool enabled) {
    _channel.invokeMethod<void>('tone', enabled).catchError((_) {});
  }

  static Future<int> playPattern(
    String code, {
    required bool sound,
    required bool vibration,
  }) async {
    try {
      return await _channel.invokeMethod<int>('playPattern', {
            'code': code,
            'sound': sound,
            'vibration': vibration,
          }) ??
          0;
    } catch (_) {
      return -1;
    }
  }

  static void stopPattern() {
    _channel.invokeMethod<void>('stopPattern').catchError((_) {});
  }

  static void vibrate(int duration) {
    _channel.invokeMethod<void>('vibrate', duration).catchError((_) {});
  }

  static void cancelVibration() {
    _channel.invokeMethod<void>('cancelVibration').catchError((_) {});
  }

  static bool get supportsVibration => true;
}
