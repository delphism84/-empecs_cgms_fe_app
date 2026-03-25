import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStorage {
  static const String storageKey = 'cgms.settings';

  static const Map<String, dynamic> defaultSettings = {
    'language': 'en',
    'region': 'KR',
    'autoRegion': true,
    'guestMode': false,
    'glucoseUnit': 'mgdl',
    'timeFormat': '24h',
    'shareConsent': false,
    'shareRange': '7',
    'shareFrom': '',
    'shareTo': '',
    'shareFamily': false,
    'shareHealth': false,
    'accHighContrast': false,
    'accLargerFont': false,
    'accColorblind': false,
    'authToken': '',
    'lastUserId': '',
    'displayName': '', // local user display (from signup or login)
    'eqsn': '',
    'notificationsEnabled': true,
    // AR_01_01: mute all alarms
    'alarmsMuteAll': false,
    // registered devices (persisted after QR & Connect)
    'registeredDevices': <Map<String, dynamic>>[],
    'lastTrid': 0,
    'lastEvid': 0,
    'chartDotSize': 2,
    'eventsSync': false,
    'offlineMode': true,
    'lastPushAtGlucose': '',
    'lastPushAtEvents': '',
    // queued ids for event deletions when offline
    'eventDeleteOutbox': <String>[],
    // API base override (dev)
    'apiBaseUrl': '',
    // last alert debug snapshot (for bot verification)
    'lastAlert': <String, dynamic>{},
    // log data transmission (support)
    'lastLogTxAt': '',
    'lastLogTxOk': false,
    // lockscreen banner notification (AR_01_08)
    'ar0108Enabled': true,
    'ar0108UpdatedAt': '',
    'lastLockScreenAt': '',
    'lastLockScreenOk': false,
    'lastLockScreenValue': null,
    'lastLockScreenTrend': '',
    // LO_01_01: login page SNS options evidence (QA/bot helpers)
    'lo0101ViewedAt': '',
    'lo0101AutoOpenEasyLoginSheet': false,
    'lo0101SheetOpenedAt': '',
    'lo0101LastProvider': '', // google/apple/kakao
    'lo0101LastProviderAt': '',
    // LO_01_02~04: SNS provider login process screens evidence
    'lo0102ViewedAt': '',
    'lo0103ViewedAt': '',
    'lo0104ViewedAt': '',
    // LO_01_08: guest mode entry evidence
    'lo0108EnteredAt': '',
    // LO_02_01~05: sign-up flow evidence
    'lo0201ViewedAt': '',
    'lo0201Choice': '', // start|later
    'lo0202ViewedAt': '',
    'lo0202AgreedAt': '',
    'lo0203ViewedAt': '',
    'lo0203Phone': '',
    'lo0203VerifiedAt': '',
    'lo0204ViewedAt': '',
    'lo0205ViewedAt': '',
    // LO_01_05: easy passcode login (4 digits)
    'passcodeEnabled': false,
    'passcodeHash': '',
    // LO_01_06 / LO_02_06: biometric login
    'biometricEnabled': false,
    // 디버그/봇용: 생체인증 팝업을 우회하여 성공 처리
    'biometricDebugBypass': false,
    // SC_01_01: permission consent + alarm range
    'sc0101Consent': false,
    'sc0101Low': 70,
    'sc0101High': 180,
    // UM_01_01: sensor attachment guide
    'um0101ViewedAt': '',
    // LO_01_07: sensor registration check viewed
    'lo0107ViewedAt': '',
    // SC_01_04: QR scan screen viewed
    'sc0104ViewedAt': '',
    // SC_01_05: manual SN entry
    'sc0105ManualSnAt': '',
    'sc0105ManualSnValue': '',
    // 마지막 스캔 QR (로컬 저장, Serial Number 페이지 등에서 표시)
    'lastScannedQrRaw': '',
    'lastScannedQrFullSn': '',
    'lastScannedQrSerial': '',
    'lastScannedQrAt': '',
    'lastScannedQrRegistered': false,
    // SC_01_06: warm-up countdown
    'sc0106WarmupStartAt': '',
    'sc0106WarmupEndsAt': '',
    'sc0106WarmupActive': false,
    'sc0106WarmupDoneAt': '',
    // SC_01_03: NFC scan guide viewed
    'sc0103ViewedAt': '',
    // SC_06_02: QR reconnect guide viewed
    'sc0602ViewedAt': '',
    'sc0602Reason': '',
    // SC_07_01: data share settings/evidence
    'sc0701ViewedAt': '',
    'sc0701Enabled': true,
    'sc0701Preset': 'Custom', // 1D/7D/30D/Custom
    'sc0701From': '',
    'sc0701To': '',
    'sc0701ItemSummary': true,
    'sc0701ItemDistribution': true,
    'sc0701ItemGraph': true,
    'sc0701ItemUserProfile': false,
    'sc0701MethodEmail': true,
    'sc0701MethodSms': false,
    'sc0701Format': 'PDF', // CSV/PDF
    'sc0701Revocable': true,
    'sc0701LastSharedAt': '',
    'sc0701LastSharedOk': false,
    'sc0701LastNote': '',
    // SC_07_01: render marker for screenshot verification
    'sc0701RenderedAt': '',
    // SC_02_01/04_01/05_01/08_01 evidence markers
    'sc0201ViewedAt': '',
    'sc0201RenderedAt': '',
    'sc0301ViewedAt': '',
    'sc0401ViewedAt': '',
    'sc0501ViewedAt': '',
    'sc0601ViewedAt': '',
    'sc0801ViewedAt': '',

    // GU_01_01~03: main glucose display evidence
    'gu0101RenderedAt': '',
    'gu0101Value': null,
    'gu0102Trend': '', // upFast/up/flat/down/downFast
    'gu0103Color': '', // low/in/high

    // TG_01_01~02: trend chart portrait/landscape evidence
    'tg0101ViewedAt': '',
    'tg0102ViewedAt': '',

    // RP_01_01: report screen evidence
    'rp0101ViewedAt': '',
    'rp0101RenderedAt': '',

    // PD_01_01: previous data view (ppt Slide 2)
    'pd0101ViewedAt': '',
    'pd0101RefreshedAt': '',
    'pd0101ItemsCount': 0,

    // ME_01_01: event editor popup evidence
    'me0101ViewedAt': '',
    'me0101SavedAt': '',
    'me0101SavedType': '',
    // ME_01_01: food shot attachment (Meal)
    'me0101FoodShotAt': '',
    'me0101FoodShotAsset': '',

    // 알람/센서: 모든 설정 기본 로컬 저장. BE는 로컬 성공 후 업로드용, 실패 시 폴백 없음.
    'alarmsCache': <Map<String, dynamic>>[],
    'alarmsCacheAt': '',
    'sensorsCache': <Map<String, dynamic>>[],
    'sensorsCacheAt': '',
  };

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      await prefs.setString(storageKey, jsonEncode(defaultSettings));
      return Map<String, dynamic>.from(defaultSettings);
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      // migration: fill missing keys
      final merged = {...defaultSettings, ...data};
      // validation: basic guards
      if (merged['language'] is! String) merged['language'] = 'en';
      if (merged['region'] is! String) merged['region'] = 'KR';
      if (merged['autoRegion'] is! bool) merged['autoRegion'] = true;
      if (merged['glucoseUnit'] is! String) merged['glucoseUnit'] = 'mgdl';
      if (merged['timeFormat'] is! String) merged['timeFormat'] = '24h';
      await prefs.setString(storageKey, jsonEncode(merged));
      return Map<String, dynamic>.from(merged);
    } catch (_) {
      await prefs.setString(storageKey, jsonEncode(defaultSettings));
      return Map<String, dynamic>.from(defaultSettings);
    }
  }

  static Future<void> save(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final merged = {...defaultSettings, ...settings};
    await prefs.setString(storageKey, jsonEncode(merged));
  }
}


