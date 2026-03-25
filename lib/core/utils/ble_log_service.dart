import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BleLogService {
  BleLogService._internal();
  static final BleLogService _instance = BleLogService._internal();
  factory BleLogService() => _instance;

  static const String _key = 'cgms.ble_logs';
  static const int _max = 500;

  final ValueNotifier<List<String>> lines = ValueNotifier<List<String>>(<String>[]);
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> stored = prefs.getStringList(_key) ?? <String>[];
    lines.value = List<String>.from(stored);
    _loaded = true;
  }

  Future<void> add(String tag, String message) async {
    await _ensureLoaded();
    final DateTime now = DateTime.now();
    final String hh = now.hour.toString().padLeft(2, '0');
    final String mm = now.minute.toString().padLeft(2, '0');
    final String ss = now.second.toString().padLeft(2, '0');
    final String ts = '$hh:$mm:$ss';
    final String line = '[$ts][$tag] $message';
    final List<String> next = <String>[line, ...lines.value];
    if (next.length > _max) {
      next.removeRange(_max, next.length);
    }
    lines.value = next;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next);
  }

  Future<void> clear() async {
    await _ensureLoaded();
    lines.value = <String>[];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<List<String>> snapshot({int limit = 120}) async {
    await _ensureLoaded();
    final int n = limit.clamp(1, _max);
    final List<String> v = lines.value;
    if (v.length <= n) return List<String>.from(v);
    return List<String>.from(v.take(n));
  }
}


