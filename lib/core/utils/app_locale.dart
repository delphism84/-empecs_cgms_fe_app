import 'dart:developer';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/app_nav.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

/// Apply app language: setLocale first, then persist only the language key.
class AppLocale {
  AppLocale._();

  static String normalize(String? raw) {
    final String v = (raw ?? 'en').toString().trim().toLowerCase();
    return v == 'ko' ? 'ko' : 'en';
  }

  static Locale toLocale(String lang) =>
      normalize(lang) == 'ko' ? const Locale('ko') : const Locale('en');

  static Future<void> apply(String lang) async {
    final String code = normalize(lang);
    final Locale loc = toLocale(code);
    log('[qa][AppLocale.apply] requested=$lang normalized=$code', name: 'qa');

    try {
      final BuildContext? root = AppNav.navigatorKey.currentContext;
      if (root != null) {
        await root.setLocale(loc);
      }
    } catch (_) {}

    LocaleBus.notify(code);

    try {
      await SettingsStorage.save(<String, dynamic>{'language': code});
      log('[qa][AppLocale.apply] persisted language=$code', name: 'qa');
    } catch (_) {}
  }

  static Future<void> applyFromStorage() async {
    try {
      final Map<String, dynamic> st = await SettingsStorage.load();
      await apply(normalize(st['language'] as String?));
    } catch (_) {}
  }
}
