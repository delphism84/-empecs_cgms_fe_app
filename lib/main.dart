import 'dart:async';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:helpcare/presentation/splash_screen/splash_screen.dart';
import 'package:helpcare/core/utils/csv_lang_loader.dart';

import 'core/theme/theme_constants.dart';
import 'core/theme/theme_manager.dart';
import 'presentation/home.dart';
import 'presentation/chart_page/chart_page.dart';
import 'presentation/chart_page/trend_tab_page.dart';
import 'presentation/statistics_screen/statistics_screen.dart';
import 'presentation/sensor_page/sensor_page.dart';
import 'presentation/sensor_page/sensor_remove_page.dart';
import 'presentation/aleart_screen/aleart_screen.dart';
import 'presentation/settings_page/settings_page.dart';
import 'presentation/report/cgms_report_screen.dart';
import 'presentation/dashboard/main_dashboard.dart';
import 'presentation/alerts/alerts_root.dart';
import 'presentation/dashboard/me_01_01_event_editor_screen.dart';
import 'presentation/dashboard/pd_01_01_previous_data_screen.dart';
import 'presentation/auth/login_choice_screen.dart';
import 'presentation/auth/lo_01_02_04_sns_login_process_screens.dart';
import 'presentation/auth/lo_02_signup_flow_screens.dart';
import 'presentation/auth/lo_02_02_terms_screen.dart';
import 'presentation/onboarding/sc_01_01_permission_range_screen.dart';
import 'presentation/onboarding/sc_01_02_reregister_screen.dart';
import 'presentation/onboarding/um_01_01_attach_guide_screen.dart';
import 'presentation/onboarding/sc_01_06_warmup_screen.dart';
import 'presentation/onboarding/sc_01_01_btstep_screen.dart';
import 'presentation/onboarding/sc_07_01_data_share_screen.dart';
import 'presentation/alarms/ar_01_01_mute_all_screen.dart';
import 'presentation/alarms/ar_01_08_lock_screen_screen.dart';
import 'presentation/alarms/alarm_type_detail_page.dart';
import 'presentation/sensor_page/sensor_qr_connect_page.dart';
import 'presentation/qa/qa_qr_scan_success_redirect.dart';
import 'presentation/settings_page/local_data_page.dart';
import 'core/utils/global_loading.dart';
import 'core/utils/notification_service.dart';
import 'core/utils/local_sync_service.dart';
import 'core/utils/online_monitor.dart';
import 'core/utils/local_db.dart';
import 'core/utils/settings_storage.dart';
import 'core/utils/ble_service.dart';
import 'core/utils/ble_emu_server.dart';
import 'core/utils/emul_ble_recv_service.dart';
import 'core/utils/alert_engine.dart';
import 'core/utils/focus_bus.dart';
import 'core/utils/app_nav.dart';
import 'core/config/social_auth_config.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;

final GlobalKey<NavigatorState> navigatorKey = AppNav.navigatorKey;

Future<Locale> _appStartLocale() async {
  try {
    final st = await SettingsStorage.load();
    final String lang = (st['language'] ?? 'en').toString().toLowerCase();
    if (lang == 'ko') return const Locale('ko');
  } catch (_) {}
  return const Locale('en');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  // QA 자동화 서버는 가장 먼저 시도해서 초기화 병목의 영향을 받지 않도록 한다.
  await BleEmuServer.maybeStart();
  await EasyLocalization.ensureInitialized();
  await CsvLangAssetLoader.preload('assets/lang/lang.csv');
  final Locale startLocale = await _appStartLocale();
  await NotificationService().initialize();
  await AlertEngine().start();
  // 로컬 DB 초기화
  await LocalDb().db;
  // 서버 pull 동기화는 비활성 (SN 변경 시에만 수동 fetch)
  try { LocalSyncService().stop(); } catch (_) {}
  // 10초마다 온라인 상태 모니터링 및 자동 push
  OnlineMonitor().start();
  // Dev gate: emulate BLE receive every 10 seconds when enabled.
  await EmulBleRecvService().start();
  // Kakao SDK 초기화 (키가 설정된 경우에만)
  if (SocialAuthConfig.hasKakaoKey) {
    kakao.KakaoSdk.init(nativeAppKey: SocialAuthConfig.kakaoNativeAppKey);
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ko')],
      path: 'assets/lang',
      assetLoader: const CsvLangAssetLoader(),
      fallbackLocale: const Locale('en'),
      startLocale: startLocale,
      saveLocale: false,
      child: const MyApp(),
    ),
  );
}

final ThemeManager appThemeManager = ThemeManager();

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLocal = false;
  bool _always24h = true;
  double _textScale = kGlobalTextScale;
  bool _accHighContrast = false;
  bool _accColorblind = false;
  bool _exitDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _init();
    AppSettingsBus.changed.addListener(_onAppSettingsChanged);
  }

  Future<void> _init() async {
    Map<String, dynamic>? st;
    try {
      final loaded = await SettingsStorage.load();
      st = loaded;
      if (!mounted) return;
      setState(() {
        _isLocal = (loaded['guestMode'] == true);
        _always24h = (loaded['timeFormat'] as String? ?? '24h') == '24h';
        final bool larger = loaded['accLargerFont'] == true;
        _textScale = kGlobalTextScale * (larger ? 1.20 : 1.0);
        _accHighContrast = loaded['accHighContrast'] == true;
        _accColorblind = loaded['accColorblind'] == true;
      });
    } catch (_) {}
    try {
      // 부팅시 BLE 상태 정리
      await BleService().disconnect(clearPersistentPairing: false);
    } catch (_) {}
    try {
      if (!mounted) return;
      final String lang = (st?['language'] ?? 'en').toString().toLowerCase();
      await context.setLocale(lang == 'ko' ? const Locale('ko') : const Locale('en'));
    } catch (_) {}
    // QA 자동화를 위해 앱 프레임 진입 후에도 EMU 서버 시작을 재시도한다.
    // 일부 기기에서 main() 초기 부팅 타이밍에 바인딩이 실패하는 경우를 보완.
    unawaited(() async {
      for (int i = 0; i < 6; i++) {
        try {
          if (BleEmuServer.boundPort != null) break;
          await BleEmuServer.maybeStart();
        } catch (_) {}
        if (BleEmuServer.boundPort != null) break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }());
  }

  void _onAppSettingsChanged() {
    () async {
      try {
        final st = await SettingsStorage.load();
        final String tf = (st['timeFormat'] as String? ?? '24h');
        if (!mounted) return;
        setState(() {
          _isLocal = (st['guestMode'] == true);
          _always24h = tf == '24h';
          final bool larger = st['accLargerFont'] == true;
          _textScale = kGlobalTextScale * (larger ? 1.20 : 1.0);
          _accHighContrast = st['accHighContrast'] == true;
          _accColorblind = st['accColorblind'] == true;
        });
        final String lang = (st['language'] ?? 'en').toString().toLowerCase();
        await context.setLocale(lang == 'ko' ? const Locale('ko') : const Locale('en'));
      } catch (_) {}
    }();
  }

  @override
  void dispose() {
    try { AppSettingsBus.changed.removeListener(_onAppSettingsChanged); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [AppNav.observer],
      builder: (context, child) {
        Future<void> handleGlobalBack() async {
          if (_exitDialogShowing) return;
          _exitDialogShowing = true;
          final bool? shouldQuit = await showDialog<bool>(
            context: navigatorKey.currentContext ?? context,
            barrierDismissible: true,
            builder: (ctx) => AlertDialog(
              title: Text('exit_app_title'.tr()),
              content: Text('exit_app_body'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('common_no'.tr()),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text('common_yes'.tr()),
                ),
              ],
            ),
          );
          _exitDialogShowing = false;
          if (shouldQuit == true) {
            await SystemNavigator.pop();
          }
        }

        final mq = MediaQuery.of(context);
        // 전역 텍스트 스케일 적용 + 우상단 로딩 인디케이터 오버레이
        final scaled = MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(_textScale),
            alwaysUse24HourFormat: _always24h,
          ),
          child: child ?? const SizedBox.shrink(),
        );
        // 요구사항: 언어 변경은 텍스트만 바꾸고, RTL(좌우 반전)은 적용하지 않음
        final fixedDir = Directionality(textDirection: ui.TextDirection.ltr, child: scaled);
        // Accessibility: 실제 화면 반영(저장만 하고 효과가 없으면 "미구현"으로 보임)
        final Widget filtered = _applyAccessibilityFilters(fixedDir);
        return Stack(
          children: [
            PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                unawaited(handleGlobalBack());
              },
              child: filtered,
            ),
            if (_isLocal)
              Positioned(
                top: mq.padding.top + 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'debug_local_badge'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            Positioned(
              top: mq.padding.top + 8,
              right: 8,
              child: ValueListenableBuilder<int>(
                valueListenable: GlobalLoading.activeCount,
                builder: (context, count, _) {
                  if (count <= 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text('common_loading'.tr(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: appThemeManager.themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: 'Glucose Care',
      home: const SplashScreen(),
      routes: {
        '/home': (_) => const Home(),
        '/login': (_) => const LoginChoiceScreen(),
        // direct QA routes (avoid bottom-nav dependency)
        '/gu/01/01': (_) => const MainDashboardPage(),
        '/pd/01/01': (_) => const Pd0101PreviousDataScreen(),
        '/tg/01/01': (_) => const TrendTabPage(),
        '/tg/01/02': (_) => const Tg0102ChartLandscapeScreen(hoursRange: '6h'),
        '/rp/01/01': (_) => const CgmsReportScreen(),
        '/me/01/01': (_) => const Me0101EventEditorScreen(),
        '/lo/01/02': (_) => const Lo0102GoogleLoginScreen(),
        '/lo/01/03': (_) => const Lo0103AppleLoginScreen(),
        '/lo/01/04': (_) => const Lo0104KakaoLoginScreen(),
        '/lo/02/01': (_) => const Lo0201SignUpIntroScreen(),
        '/lo/02/02': (_) => const Lo0202TermsScreen(),
        '/lo/02/04': (_) => const Lo0204UserInfoWrapperScreen(),
        '/lo/02/05': (_) => const Lo0205SignUpCompleteScreen(),
        '/sc/01/01': (_) => const Sc0101PermissionRangeScreen(),
        '/sc/01/02': (_) => const Sc0102ReregisterScreen(),
        '/sc/01/04': (_) => const SensorQrConnectPage(title: 'QR Sensor Scan', reqId: 'SC_01_04'),
        '/sc/01/05': (_) => const SensorSerialPage(),
        '/sc/01/06': (_) => const Sc0106WarmupScreen(),
        // SC_01_01 (PPTX 기준) Scan & Connect 전용 라우트
        '/sc/01/01/scan': (_) => const SensorBleScanPage(),
        '/sc/01/01/btstep': (_) => const Sc0101BtStepScreen(),
        '/sc/07/01': (_) => const Sc0701DataShareScreen(),
        '/ar/01/01': (_) => const Ar0101MuteAllScreen(),
        '/ar/01/02': (_) => const AlarmTypeDetailPage(type: 'very_low', title: 'Very Low (AR_01_02)', reqId: 'AR_01_02'),
        '/ar/01/03': (_) => const AlarmTypeDetailPage(type: 'high', title: 'High (AR_01_03)', reqId: 'AR_01_03'),
        '/ar/01/04': (_) => const AlarmTypeDetailPage(type: 'low', title: 'Low (AR_01_04)', reqId: 'AR_01_04'),
        '/ar/01/05': (_) => const AlarmTypeDetailPage(type: 'rate', title: 'Rapid Change (AR_01_05)', reqId: 'AR_01_05'),
        '/ar/01/08': (_) => const Ar0108LockScreenScreen(),
        // AR_01_01 알람 설정 루트(홈 탭 의존 없이 QA 캡처용)
        '/ar/root': (_) => AlertsRootPage(),
        '/um/01/01': (_) => const Um0101AttachGuideScreen(),
        '/chart': (_) => const ChartPage(),
        '/stats': (_) => const StatisticsScreen(),
        '/sensor': (_) => const SensorPage(),
        '/sensor/remove': (_) => SensorRemovePage(),
        // Sensor sub-pages (named for QA/automation)
        '/sc/02/01': (_) => const SensorPage(),
        '/sc/03/01': (_) => const SensorStatusPage(),
        '/sc/04/01': (_) => const SensorSerialPage(),
        '/sc/05/01': (_) => const SensorStartTimePage(),
        '/sc/06/01': (_) => const SensorReconnectNfcPage(),
        '/sc/08/01': (_) => const SensorRemovePageWrapper(),
        '/alerts': (_) => const AleartScreen(),
        '/settings': (_) => const SettingsPage(),
        '/data/local': (_) => const LocalDataPage(),
        '/qa/qr-scan-success': (_) => const QaQrScanSuccessRedirect(),
      },
    );
  }

  Widget _applyAccessibilityFilters(Widget child) {
    Widget w = child;
    if (_accColorblind) {
      // stronger desaturation (color blind aid; make effect obvious in QA)
      const double s = 0.25;
      const double inv = 1 - s;
      const double r = 0.2126;
      const double g = 0.7152;
      const double b = 0.0722;
      final m = <double>[
        inv * r + s, inv * g, inv * b, 0, 0,
        inv * r, inv * g + s, inv * b, 0, 0,
        inv * r, inv * g, inv * b + s, 0, 0,
        0, 0, 0, 1, 0,
      ];
      w = ColorFiltered(colorFilter: ColorFilter.matrix(m), child: w);
    }
    if (_accHighContrast) {
      // stronger contrast boost (make effect obvious in QA)
      const double c = 1.35;
      const double t = (1 - c) * 128; // keep mid-tones roughly centered
      final m = <double>[
        c, 0, 0, 0, t,
        0, c, 0, 0, t,
        0, 0, c, 0, t,
        0, 0, 0, 1, 0,
      ];
      w = ColorFiltered(colorFilter: ColorFilter.matrix(m), child: w);
    }
    return w;
  }
}
