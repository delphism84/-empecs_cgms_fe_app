import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:helpcare/core/utils/ingest_queue.dart';
import 'package:helpcare/core/utils/glucose_local_repo.dart';
// removed direct DataSyncBus usage; ingestion queue handles broadcast
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/core/utils/debug_toast.dart';
import 'package:helpcare/core/utils/data_sync_bus.dart';
import 'package:helpcare/core/utils/ble_log_service.dart';
import 'package:helpcare/core/utils/foreground_service_bridge.dart';
import 'package:helpcare/core/utils/app_nav.dart';
import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/sensor_usage.dart';
import 'package:helpcare/core/utils/sensor_warmup_service.dart';
import 'package:helpcare/core/utils/warmup_state.dart';
import 'package:helpcare/core/utils/background_sync_gate.dart';
import 'package:helpcare/core/utils/ble_auto_pair_store.dart';
import 'package:helpcare/core/utils/crash_logger.dart';

class _CgmsSample {
  _CgmsSample({required this.value, required this.offsetMin});

  final double value;

  /// CGM Measurement(0x2AA7)의 `Time Offset` — 세션 시작으로부터의 **분**.
  /// CGMS 스펙상 이 값이 레코드의 실제 식별자다(별도 sequence number 없음).
  /// 예전 코드는 이 필드를 건너뛰고 모든 레코드에 `DateTime.now()`를 찍어,
  /// RACP 백필 이력이 전부 "재연결한 시각"으로 몰려 기록됐다.
  final int offsetMin;
}


class BleService {
  BleService._internal();
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;

  FlutterReactiveBle? _ble;
  FlutterReactiveBle get _nativeBle {
    if (kIsWeb) {
      throw UnsupportedError('BLE is not available on web');
    }
    return _ble ??= FlutterReactiveBle();
  }
  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<List<int>>? _opsIndSub;
  StreamSubscription<List<int>>? _racpIndSub;

  String? _currentDeviceId;
  bool _historyInProgress = false;
  Timer? _historyDebounce;
  Timer? _historyTimeout;

  /// 이력(RACP 백필) 수신 창을 닫는다. 열려 있는 동안 도착한 패킷은 실시간이 아닌
  /// 이력으로 취급돼 UI 즉시 반영·잠금화면 배너가 억제되므로, 필요 이상으로 열어두면 안 된다.
  void _endHistoryMode(String reason) {
    _historyTimeout?.cancel();
    _historyTimeout = null;
    if (!_historyInProgress) return;
    _historyInProgress = false;
    unawaited(BleLogService().add('CGMS', 'history mode end ($reason)'));
  }

  /// Pairing UI (QR flow): [connectToDeviceAndWaitReady] waits until GATT is usable.
  Completer<bool>? _pairingCompleter;
  String? _pairingDeviceId;

  // note: no persistent device cache here; using SharedPreferences for last_mac

  // connection/ops state for UI
  final ValueNotifier<BleConnPhase> phase = ValueNotifier<BleConnPhase>(BleConnPhase.off);
  // expose current connected device id (null when disconnected)
  final ValueNotifier<String?> connectedDeviceId = ValueNotifier<String?>(null);
  // simple scanning flag for UI (true when actively scanning)
  final ValueNotifier<bool> scanning = ValueNotifier<bool>(false);

  // notify 수신 버퍼 개수 (누적)
  final ValueNotifier<int> rxCount = ValueNotifier<int>(0);

  /// 끊김 후 마지막 MAC으로 주기적 자동 재연결
  Timer? _autoReconnectTimer;
  /// 첫 재연결 시도 전 5~10초 구간(링크 안정화·스캔 준비)
  Timer? _firstReconnectKickTimer;
  /// 링크 손실 알람(AR_01_06) 설정 주기만큼 재발화 — disconnect 이벤트는 1회만 오므로 타이머로 보강
  Timer? _signalLossRepeatTimer;
  /// [listAlarms] await 중·자동 재연결로 phase가 잠깐 connecting이면 체인이 끊기지 않게 짧게 재시도
  Timer? _signalLossChainRetryTimer;
  /// 사용자가 설정/센서 화면에서 [disconnect]를 호출한 경우, 링크 손실 알람(AR_01_06)을 띄우지 않음.
  bool _userInitiatedDisconnect = false;
  /// CGM measurement notify 구독 성공 후에만 true — 접속 전·구독 실패 시 AR_01_06(signal loss) 알림 없음.
  bool _ar0106SessionReady = false;
  bool _notifySubscribeInFlight = false;
  Timer? _notifyRetryTimer;
  int _notifyRetryCount = 0;
  DateTime? _lastNotifyErrorToastAt;
  // discovered capabilities (updated by _validateCgmsProfile)
  bool _measFound = false;
  bool _measNotify = false;
  bool _opsFound = false;
  bool _opsWrite = false;
  bool _opsInd = false;

  // CGM Service/Characteristics (Bluetooth SIG Assigned Numbers)
  // Service: 0x181F (Continuous Glucose Monitoring)
  // CGM Measurement: 0x2AA7, CGM Specific Ops Control Point: 0x2AAC
  static final Uuid serviceCgms = Uuid.parse("0000181F-0000-1000-8000-00805F9B34FB");
  static final Uuid charMeasurement = Uuid.parse("00002AA7-0000-1000-8000-00805F9B34FB");
  static final Uuid charOpsControl = Uuid.parse("00002AAC-0000-1000-8000-00805F9B34FB");
  // Record Access Control Point (RACP) - used for stored records count/fetch
  static final Uuid charRacp = Uuid.parse("00002A52-0000-1000-8000-00805F9B34FB");
  // Glucose Service (RACP belongs to 0x1808 per SIG; some devices may still expose under CGMS)
  static final Uuid serviceGlucose = Uuid.parse("00001808-0000-1000-8000-00805F9B34FB");
  // Current Time Service/Characteristic for time sync
  static final Uuid serviceCurrentTime = Uuid.parse("00001805-0000-1000-8000-00805F9B34FB");
  static final Uuid charCurrentTime = Uuid.parse("00002A2B-0000-1000-8000-00805F9B34FB");

  // Device Information Service/Characteristics (for SN read)
  static final Uuid serviceDeviceInfo = Uuid.parse("0000180A-0000-1000-8000-00805F9B34FB");
  // 0x2A25: Serial Number String
  static final Uuid charSerialNumberString = Uuid.parse("00002A25-0000-1000-8000-00805F9B34FB");

  Future<void> ensurePermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Stream<DiscoveredDevice> scanCgms({Duration timeout = const Duration(seconds: 8)}) async* {
    await ensurePermissions();
    phase.value = BleConnPhase.scanning;
    scanning.value = true;
    DebugToastBus().show('BLE: scanning CGMS');
    unawaited(BleLogService().add('BLE', 'scan start CGMS (broad)'));
    final controller = StreamController<DiscoveredDevice>();
    final Set<String> seen = <String>{};
    bool any = false;
    bool isCgmsAdv(DiscoveredDevice d) {
      try {
        // service UUID match
        if (d.serviceUuids.any((u) => u == serviceCgms)) return true;
      } catch (_) {}
      final String n = (d.name).toUpperCase();
      // common CGM vendor/name hints
      const List<String> hints = [
        'CGM', 'DEXCOM', 'LIBRE', 'FREESTYLE', 'ABBOTT', 'MEDTRONIC', 'ASCENSIA', 'EVER', 'SENSE', 'GLUCO', 'DUSUN', 'EMPECS'
      ];
      for (final h in hints) {
        if (n.contains(h)) return true;
      }
      return false;
    }
    void addIfMatch(DiscoveredDevice d) {
      if (!isCgmsAdv(d)) return;
      if (seen.add(d.id)) {
        any = true;
        controller.add(d);
        unawaited(BleLogService().add('BLE', 'discover ${d.name} (${d.id}) uuids=' + d.serviceUuids.map((e)=>e.toString()).join(',')));
      }
    }
    _scanSub?.cancel();
    // broad scan (no service filter) to capture devices that don't advertise 0x181F
    _scanSub = _nativeBle.scanForDevices(withServices: const [], scanMode: ScanMode.lowLatency).listen(addIfMatch);
    // stop after timeout
    Future.delayed(timeout, () async {
      await _scanSub?.cancel();
      await controller.close();
      if (phase.value == BleConnPhase.scanning) {
        phase.value = BleConnPhase.off;
      }
      scanning.value = false;
      unawaited(BleLogService().add('BLE', 'scan stop' + (any ? '' : ' (no matches)')));
    });
    yield* controller.stream;
  }

  void _completePairingIfPending(String deviceId, bool ok) {
    if (_pairingDeviceId == deviceId && _pairingCompleter != null && !_pairingCompleter!.isCompleted) {
      _pairingCompleter!.complete(ok);
      _pairingCompleter = null;
      _pairingDeviceId = null;
      unawaited(BleLogService().add('BLE', 'pairing ${ok ? 'ready' : 'fail'} $deviceId'));
    }
  }

  /// Waits until the device is connected and services are discovered (same as [connectToDevice] first phase).
  /// Use for QR pairing before comparing scan MAC vs QR or reading DIS serial.
  Future<bool> connectToDeviceAndWaitReady(String deviceId) async {
    await ensurePermissions();
    _pairingCompleter = Completer<bool>();
    _pairingDeviceId = deviceId;
    await connectToDevice(deviceId);
    try {
      return await _pairingCompleter!.future.timeout(const Duration(seconds: 25));
    } on TimeoutException {
      unawaited(BleLogService().add('BLE', 'pairing timeout $deviceId'));
      if (_pairingCompleter != null && !_pairingCompleter!.isCompleted) {
        _pairingCompleter!.complete(false);
      }
      _pairingCompleter = null;
      _pairingDeviceId = null;
      try {
        await disconnect();
      } catch (_) {}
      return false;
    }
  }

  Future<void> connectToDevice(String deviceId) async {
    await ensurePermissions();
    // Signal-loss repeat chain must survive reconnect attempts; cancel only on
    // successful CGM notify subscribe or explicit [disconnect].
    // keep only a single connection:
    // 1) if already connected/connecting to the same device, ignore
    if (_currentDeviceId != null && _currentDeviceId == deviceId && phase.value != BleConnPhase.off) {
      DebugToastBus().show('BLE: already connected/connecting');
      _completePairingIfPending(deviceId, true);
      return;
    }
    // 2) stop scanning before connecting
    try { await _scanSub?.cancel(); } catch (_) {}
    scanning.value = false;
    // 3) if another connection exists, disconnect first
    if (phase.value != BleConnPhase.off && _currentDeviceId != null) {
      try { await disconnect(clearPersistentPairing: false); } catch (_) {}
    }
    _ar0106SessionReady = false;
    phase.value = BleConnPhase.connecting;
    DebugToastBus().show('BLE: connecting to $deviceId');
    unawaited(BleLogService().add('BLE', 'connect -> $deviceId'));
    _connSub?.cancel();
    _connSub = _nativeBle.connectToDevice(id: deviceId, connectionTimeout: const Duration(seconds: 8)).listen((update) async {
      if (update.connectionState == DeviceConnectionState.connected) {
        _stopAutoReconnectPoller();
        phase.value = BleConnPhase.connected;
        DebugToastBus().show('BLE: connected');
        unawaited(BleLogService().add('BLE', 'connected'));
        // 연결 성공(=BT 권한 확보) 시점에 백그라운드 유지 Foreground Service 시작.
        unawaited(CgmsForegroundService.start());
        try {
          _currentDeviceId = deviceId;
          connectedDeviceId.value = deviceId;
          // validate CGMS profile (service/characteristics/properties) - MUST await to avoid race
          await _validateCgmsProfile(deviceId);
          _completePairingIfPending(deviceId, true);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cgms.last_mac', deviceId);
          } catch (_) {}
          // 센서 시작 시각: 서버 로그인 직후 첫 연결은 접속 시각(재연결 검수). 그 외 eqsn 있으면 서버 startAt 우선.
          try {
            final st = await SettingsStorage.load();
            final String eqsn = (st['eqsn'] as String? ?? '').trim();
            final DateTime now = DateTime.now().toUtc();
            bool dirty = SettingsService.stripStaleSensorStart(st);
            final SettingsService ss = SettingsService();
            final bool resetStartAfterLogin = st['resetSensorStartOnNextBleAttach'] == true;
            if (resetStartAfterLogin) {
              st['resetSensorStartOnNextBleAttach'] = false;
              dirty = true;
              if (eqsn.isNotEmpty) {
                st['sensorStartAt'] = now.toIso8601String();
                st['sensorStartAtEqsn'] = eqsn;
                try {
                  await ss.upsertEqStart(serial: eqsn, startAt: now);
                } catch (_) {}
              }
            } else if (eqsn.isNotEmpty) {
              if (SettingsService.stripStaleSensorStart(st)) dirty = true;
              BackgroundSyncGate.runWhenUnblocked(
                () => SensorUsage.syncStartAtWithServer(bleMac: deviceId),
                dedupeKey: 'sensorStartSync',
              );
            } else {
              final String existingStart = (st['sensorStartAt'] as String? ?? '').trim();
              if (existingStart.isEmpty) {
                st['sensorStartAt'] = now.toIso8601String();
                st['sensorStartAtEqsn'] = '';
                dirty = true;
              }
            }
            if (dirty) {
              await SettingsStorage.save(st);
              try {
                DataSyncBus().emitGlucoseBulk(count: 1);
              } catch (_) {}
            }
            unawaited(SensorWarmupService.ensureWarmupWindowForCurrentSnIfMissing());
          } catch (_) {}
          // NRF Toolbox 스타일: CCCD 먼저 on (RACP indicate, Measurement notify)
          try { await _subscribeRacp(deviceId); } catch (_) {}
          try { await _subscribeGlucose(deviceId); } catch (_) {}
          // OPS Indication 구독 → Start Session → ACK 확인
          bool opsAck = false;
          try {
            opsAck = await _subscribeOpsAndStart(deviceId);
            if (opsAck) phase.value = BleConnPhase.opsStarted;
            DebugToastBus().show('CGMS: ops start ${opsAck ? 'ack' : 'no-ack'}');
            unawaited(BleLogService().add('CGMS', 'ops start ${opsAck ? 'ack' : 'no-ack'}'));
          } catch (_) {
            DebugToastBus().show('CGMS: ops start fail');
            unawaited(BleLogService().add('CGMS', 'ops start exception'));
          }
          // RACP Indication 구독 (히스토리 동기화용)
          try {
            await _subscribeRacp(deviceId);
          } catch (_) {}
          // time sync (best-effort)
          try {
            final bool ts = await _syncTime(deviceId);
            if (ts) phase.value = BleConnPhase.timeSynced;
            DebugToastBus().show('CGMS: time sync ${ts ? 'ok' : 'skip'}');
            unawaited(BleLogService().add('CGMS', 'time sync ${ts ? 'ok' : 'skip'}'));
          } catch (_) {
            DebugToastBus().show('CGMS: time sync fail');
            unawaited(BleLogService().add('CGMS', 'time sync exception'));
          }
        } finally {
          if (phase.value != BleConnPhase.notifySubscribed) {
            await _subscribeGlucose(deviceId);
          }
          // 로컬 기준 누락 TRID 보충 (RACP)
          unawaited(_racpFillMissingFromLocal());
        }
      }
      if (update.connectionState == DeviceConnectionState.disconnected) {
        _completePairingIfPending(deviceId, false);
        phase.value = BleConnPhase.off;
        _currentDeviceId = null;
        connectedDeviceId.value = null;
        unawaited(BleLogService().add('BLE', 'disconnected (range/timeout/user) — 로컬 기록'));
        final bool skipLinkAlarm = _userInitiatedDisconnect;
        _userInitiatedDisconnect = false;
        final bool hadCgmNotify = _ar0106SessionReady;
        _ar0106SessionReady = false;
        if (!skipLinkAlarm && hadCgmNotify) {
          unawaited(AlertEngine().notifyBleLinkLost());
          _scheduleSignalLossRepeats();
        }
        // 사용자 Disconnect로 MAC을 지운 뒤 늦게 도착하는 disconnected에서도 폴링이 다시 케이지 않도록,
        // 저장된 last_mac이 있을 때만 자동 재연결(SC_01_01 등 “의도적 끊김” 후 반복 연결 시도 방지).
        unawaited(() async {
          try {
            if (await BleAutoPairStore.hasPair()) {
              _startAutoReconnectPoller();
            }
          } catch (_) {}
        }());
      }
    });
  }

  void _cancelSignalLossRepeatTimer() {
    _signalLossChainRetryTimer?.cancel();
    _signalLossChainRetryTimer = null;
    _signalLossRepeatTimer?.cancel();
    _signalLossRepeatTimer = null;
  }

  void _armSignalLossChainRetry(Duration delay) {
    _signalLossChainRetryTimer?.cancel();
    _signalLossChainRetryTimer = Timer(delay, () {
      _signalLossChainRetryTimer = null;
      unawaited(_runSignalLossRepeatChain());
    });
  }

  Future<int> _systemSignalLossRepeatMinutes() async {
    try {
      final list = await SettingsService().listAlarms();
      for (final raw in list) {
        if ((raw['type'] ?? '').toString() == 'system') {
          return SettingsService.parseAlarmRepeatMinutes(raw['repeatMin']);
        }
      }
    } catch (_) {}
    return SettingsService.parseAlarmRepeatMinutes(null);
  }

  void _scheduleSignalLossRepeats() {
    _cancelSignalLossRepeatTimer();
    unawaited(_runSignalLossRepeatChain());
  }

  /// disconnect 이벤트는 1회뿐이라, 이후 재알림은 타이머로만 가능.
  /// [Timer.periodic]은 최초 간격만 고정되어 저장된 repeatMin 변경이 반영되지 않을 수 있어,
  /// 원샷 타이머를 연쇄하고 매번 [listAlarms]에서 간격을 다시 읽는다.
  /// 앱이 백그라운드일 때는 OS가 Dart 타이머를 지연시킬 수 있음(배터리 정책).
  Future<void> _runSignalLossRepeatChain() async {
    BleConnPhase ph = phase.value;
    if (ph == BleConnPhase.notifySubscribed) {
      _cancelSignalLossRepeatTimer();
      return;
    }
    if (ph != BleConnPhase.off) {
      // GATT 연결·OPS·타임싱크 등 중간 단계: 체인을 끊지 않고 짧게 재확인
      if (ph == BleConnPhase.scanning ||
          ph == BleConnPhase.connecting ||
          ph == BleConnPhase.connected ||
          ph == BleConnPhase.opsStarted ||
          ph == BleConnPhase.timeSynced) {
        _armSignalLossChainRetry(const Duration(seconds: 3));
      }
      return;
    }
    final int mins = await _systemSignalLossRepeatMinutes();
    ph = phase.value;
    if (ph == BleConnPhase.notifySubscribed) {
      _cancelSignalLossRepeatTimer();
      return;
    }
    if (ph != BleConnPhase.off) {
      if (ph == BleConnPhase.scanning ||
          ph == BleConnPhase.connecting ||
          ph == BleConnPhase.connected ||
          ph == BleConnPhase.opsStarted ||
          ph == BleConnPhase.timeSynced) {
        _armSignalLossChainRetry(const Duration(seconds: 3));
      }
      return;
    }
    final int safeMins = mins.clamp(1, 120);
    _signalLossRepeatTimer?.cancel();
    _signalLossRepeatTimer = Timer(Duration(minutes: safeMins), () {
      unawaited(() async {
        BleConnPhase ph = phase.value;
        if (ph == BleConnPhase.scanning || ph == BleConnPhase.connecting) {
          _armSignalLossChainRetry(const Duration(seconds: 3));
          return;
        }
        if (ph == BleConnPhase.notifySubscribed) {
          _cancelSignalLossRepeatTimer();
          return;
        }
        if (ph != BleConnPhase.off) {
          _armSignalLossChainRetry(const Duration(seconds: 3));
          return;
        }
        await AlertEngine().notifyBleLinkLost(fromScheduledRepeat: true);
        ph = phase.value;
        if (ph == BleConnPhase.scanning || ph == BleConnPhase.connecting) {
          _armSignalLossChainRetry(const Duration(seconds: 3));
          return;
        }
        if (ph == BleConnPhase.notifySubscribed) {
          _cancelSignalLossRepeatTimer();
          return;
        }
        if (ph != BleConnPhase.off) {
          _armSignalLossChainRetry(const Duration(seconds: 3));
          return;
        }
        await _runSignalLossRepeatChain();
      }());
    });
  }

  /// Signal Loss 알람에서 반복(분) 저장 후, 링크가 아직 끊긴 상태면 다음 대기를 새 간격으로 다시 잡는다.
  void rescheduleSignalLossRepeatsIfDisconnected() {
    if (phase.value != BleConnPhase.off) return;
    _scheduleSignalLossRepeats();
  }

  /// Starts (or resumes) the 30-minute warm-up flow and navigates to `SC_01_06`.
  /// This is triggered by the UI ("Sensor Connect") after the user sees the BT step guide.
  Future<void> startWarmupAndNavigate({int seconds = 30 * 60}) async {
    try {
      final st = await SettingsStorage.load();
      final String eqsn = (st['eqsn'] as String? ?? '').trim();
      final String lastEqsn = (st['sc0106WarmupEqsn'] as String? ?? '').trim();

      // if sensor changed, reset warm-up completion marker so next connect starts warm-up again
      if (eqsn.isNotEmpty && lastEqsn.isNotEmpty && eqsn != lastEqsn) {
        st['sc0106WarmupDoneAt'] = '';
        st['sc0106WarmupActive'] = false;
        await SettingsStorage.save(st);
      }

      // 저장 플래그만 보지 않음: isActive()가 만료·정리까지 반영(플래그 불일치 시 알람 새는 케이스 방지)
      final bool liveWarmup = await WarmupState.isActive();
      if (liveWarmup) {
        if (AppNav.route != '/sc/01/06') await AppNav.goNamed('/sc/01/06');
        return;
      }

      final bool doneFlag = (st['sc0106WarmupDoneAt'] as String? ?? '').trim().isNotEmpty;
      if (doneFlag) {
        // 이미 SC_01_06 웜업이 끝난 세션 — 재연결·QR 후에 웜업 화면으로 되돌리지 않음
        return;
      }

      // Start warm-up
      await WarmupState.start(seconds: seconds, eqsn: eqsn);
      await SensorWarmupService.beginWarmup(eqsn, durationSec: seconds);
      AlertEngine().invalidateWarmupCache();

      unawaited(BleLogService().add('CGMS', 'warmup start ${seconds}s (eqsn=${eqsn.isEmpty ? '—' : eqsn})'));
      if (AppNav.route != '/sc/01/06') {
        await AppNav.goNamed('/sc/01/06');
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _validateCgmsProfile(String deviceId) async {
    try {
      final List<DiscoveredService> services = await _nativeBle.discoverServices(deviceId);
      DiscoveredService? svc;
      for (final DiscoveredService ds in services) {
        if (ds.serviceId == serviceCgms) { svc = ds; break; }
      }
      if (svc == null) {
        DebugToastBus().show('CGMS: service 0x181F not found');
        unawaited(BleLogService().add('CGMS', 'service 0x181F not found'));
        return;
      }
      DebugToastBus().show('CGMS: service OK');
      unawaited(BleLogService().add('CGMS', 'service OK'));
      // collect props from discovered services
      bool measFound = false; bool measNotify = false;
      bool opsFound = false; bool opsWrite = false; bool opsInd = false;
      for (final DiscoveredService ds in services) {
        for (final DiscoveredCharacteristic c in ds.characteristics) {
          if (c.characteristicId == charMeasurement) {
            measFound = true; measNotify = c.isNotifiable;
          }
          if (c.characteristicId == charOpsControl) {
            opsFound = true; opsWrite = c.isWritableWithResponse || c.isWritableWithoutResponse; opsInd = c.isIndicatable;
          }
        }
      }
      DebugToastBus().show('CGMS: meas ${measFound ? 'OK' : 'MISS'} notify=${measNotify ? 'Y' : 'N'}');
      DebugToastBus().show('CGMS: ops  ${opsFound ? 'OK' : 'MISS'} write=${opsWrite ? 'Y' : 'N'} ind=${opsInd ? 'Y' : 'N'}');
      unawaited(BleLogService().add('CGMS', 'meas ${measFound ? 'OK' : 'MISS'} notify=${measNotify ? 'Y' : 'N'}'));
      unawaited(BleLogService().add('CGMS', 'ops  ${opsFound ? 'OK' : 'MISS'} write=${opsWrite ? 'Y' : 'N'} ind=${opsInd ? 'Y' : 'N'}'));
      // persist capabilities for safe subscription later
      _measFound = measFound;
      _measNotify = measNotify;
      _opsFound = opsFound;
      _opsWrite = opsWrite;
      _opsInd = opsInd;
    } catch (_) {
      DebugToastBus().show('CGMS: profile validate failed');
      unawaited(BleLogService().add('CGMS', 'profile validate failed'));
    }
  }

  static String _bleAddressKey(String id) =>
      id.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();

  /// 자동 재연결은 [BleAutoPairStore]에 저장된 MAC만 사용(cgms.last_mac·QR MAC 미사용).
  Future<String?> _autoPairTargetId() async => BleAutoPairStore.read();

  /// 사용자 성공 접속(QR·수동 Connect) 후에만 자동 재연결 대상 MAC을 등록.
  static Future<void> registerAutoPairTarget(String deviceId) =>
      BleAutoPairStore.save(deviceId);

  Future<void> tryAutoReconnect() async {
    final String? id = await _autoPairTargetId();
    if (id == null || id.isEmpty) return;
    BleAutoPairStore.showAutoPairingToast();
    unawaited(BleLogService().add('BLE', 'auto-pair -> $id'));
    unawaited(connectToDevice(id));
  }

  void _startAutoReconnectPoller() {
    _stopAutoReconnectPoller();
    // 5~10초: 무선 스택·센서 쪽이 안정된 뒤 첫 시도
    _firstReconnectKickTimer = Timer(const Duration(seconds: 8), () {
      if (phase.value == BleConnPhase.off) {
        unawaited(tryAutoReconnect());
      }
    });
    _autoReconnectTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (phase.value == BleConnPhase.connecting) return;
      if (phase.value != BleConnPhase.off) return;
      if (!await BleAutoPairStore.hasPair()) return;
      unawaited(BleLogService().add('BLE', 'auto-pair poll'));
      unawaited(tryAutoReconnect());
    });
  }

  void _stopAutoReconnectPoller() {
    _firstReconnectKickTimer?.cancel();
    _firstReconnectKickTimer = null;
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = null;
  }

  void _cancelNotifyRetryTimer() {
    _notifyRetryTimer?.cancel();
    _notifyRetryTimer = null;
  }

  Future<void> _refreshCgmsDiscovery(String deviceId) async {
    try {
      await _validateCgmsProfile(deviceId);
    } catch (_) {}
  }

  Future<void> _onNotifySubscribeFailed(String deviceId, Object? error, String reason) async {
    try {
      await _notifySub?.cancel();
    } catch (_) {}
    _notifySub = null;
    _ar0106SessionReady = false;
    if (phase.value == BleConnPhase.off) return;

    unawaited(BleLogService().add('CGMS', 'notify stream ended: $reason ${error ?? ''}'));

    final DateTime now = DateTime.now();
    if (reason == 'error' &&
        (_lastNotifyErrorToastAt == null ||
            now.difference(_lastNotifyErrorToastAt!) > const Duration(seconds: 30))) {
      _lastNotifyErrorToastAt = now;
      DebugToastBus().show('CGMS: notify error');
    }

    _scheduleNotifyRetry(deviceId);
  }

  void _scheduleNotifyRetry(String deviceId) {
    _cancelNotifyRetryTimer();
    if (phase.value == BleConnPhase.off) return;

    _notifyRetryCount++;
    final int delaySec = _notifyRetryCount > 10
        ? 60
        : min(2 * _notifyRetryCount, 30);

    _notifyRetryTimer = Timer(Duration(seconds: delaySec), () async {
      if (phase.value == BleConnPhase.off) return;
      if (_notifyRetryCount > 10) {
        _notifyRetryCount = 0;
      }
      await _refreshCgmsDiscovery(deviceId);
      if (!_measFound || !_measNotify) {
        unawaited(BleLogService().add('CGMS', 'notify retry skip — char still missing'));
        _scheduleNotifyRetry(deviceId);
        return;
      }
      unawaited(_subscribeGlucose(deviceId));
    });
  }

  Future<void> _subscribeGlucose(String deviceId) async {
    if (_notifySubscribeInFlight) return;
    if (phase.value == BleConnPhase.off) return;
    _notifySubscribeInFlight = true;
    try {
      _cancelNotifyRetryTimer();

      if (!_measFound || !_measNotify) {
        await _refreshCgmsDiscovery(deviceId);
      }
      if (!_measFound || !_measNotify) {
        DebugToastBus().show('CGMS: measurement char missing or not notifiable; skip subscribe');
        unawaited(BleLogService().add('CGMS', 'skip meas subscribe (missing/notifiable)'));
        _scheduleNotifyRetry(deviceId);
        return;
      }

      try {
        await _notifySub?.cancel();
      } catch (_) {}
      _notifySub = null;

      final ch = QualifiedCharacteristic(serviceId: serviceCgms, characteristicId: charMeasurement, deviceId: deviceId);
      DebugToastBus().show('CGMS: subscribe notify');
      unawaited(BleLogService().add('CGMS', 'subscribe notify'));

      try {
        final Stream<List<int>> stream = _nativeBle.subscribeToCharacteristic(ch);
        _notifySub = stream.listen(
          (data) {
            unawaited(_handleCgmsNotifyPacket(data, source: 'ble', silent: _historyInProgress));
          },
          onError: (e, st) {
            unawaited(_onNotifySubscribeFailed(deviceId, e, 'error'));
          },
          onDone: () {
            unawaited(_onNotifySubscribeFailed(deviceId, null, 'done'));
          },
          cancelOnError: false,
        );
      } catch (e) {
        await _onNotifySubscribeFailed(deviceId, e, 'catch');
        return;
      }

      phase.value = BleConnPhase.notifySubscribed;
      _ar0106SessionReady = true;
      _notifyRetryCount = 0;
      _cancelSignalLossRepeatTimer();
    } finally {
      _notifySubscribeInFlight = false;
    }
  }

  Future<void> _handleCgmsNotifyPacket(List<int> data, {required String source, required bool silent}) async {
    // increment buffer count per notify packet
    rxCount.value = rxCount.value + 1;
    // raw debug log (length + hex)
    try {
      final String hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      unawaited(BleLogService().add('CGMS', '$source notify raw len=${data.length} [${hex}]'));
    } catch (_) {}

    final List<_CgmsSample> records = _parseCgmsMeasurements(data);
    if (records.isEmpty) {
      unawaited(BleLogService().add('CGMS', '$source notify parse skipped (len=${data.length})'));
      return;
    }

    try {
      final st = await SettingsStorage.load();
      final String eqsn = (st['eqsn'] as String? ?? '');
      final String userId = (st['lastUserId'] as String? ?? '');

      // ── trid 워터마크 복구 ──────────────────────────────────────────────
      // trid 는 기기 값이 아니라 앱이 만드는 카운터다. 설정 파일이 초기화되거나
      // 파싱에 실패해 0으로 되돌아가면 예전에는 그대로 1,2,3… 을 다시 발급해
      // 기존 행과 충돌시켰다. 저장된 값과 **DB 실측 최대값** 중 큰 쪽에서 이어간다.
      final int stored = (st['lastTrid'] as num?)?.toInt() ?? 0;
      final int dbMax = await GlucoseLocalRepo().maxTrid(eqsn: eqsn, userId: userId, src: GlucoseSrc.ble);
      int last = stored >= dbMax ? stored : dbMax;
      if (dbMax > stored) {
        unawaited(BleLogService().add('CGMS', 'lastTrid recovered $stored → $dbMax (db max)'));
      }

      // ── 세션 기준시각 ─────────────────────────────────────────────────
      // 레코드 시각 = (세션 시작) + offsetMin. 실시간 수신은 now ≈ 실제 측정시각이므로
      // 첫 실시간 샘플에서 base = now - offset 을 구해 저장하고, 이후 RACP 백필은
      // 그 base 로 과거 시각을 복원한다(재연결 시각에 몰아 찍지 않는다).
      final int? base = await _resolveSessionBaseMs(st, records, live: !silent, eqsn: eqsn);

      int bulkCount = 0;
      for (final _CgmsSample r in records) {
        last = _nextTrid(last);
        final DateTime t = (base == null)
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(base + r.offsetMin * 60000);
        DebugToastBus().show('CGMS: $source v=${r.value.toStringAsFixed(0)} off=${r.offsetMin}m');
        unawaited(BleLogService().add(
            'CGMS', '$source v=${r.value.toStringAsFixed(0)} off=${r.offsetMin}m t=${t.toIso8601String()} trid=$last'));
        // 캐시/브로드캐스트/업로드는 큐 서비스 단일 경로로 처리 (중복 제거)
        IngestQueueService().enqueueGlucose(t, r.value, trid: last, eqsn: eqsn, userId: userId, silent: silent);
        if (silent) {
          bulkCount++;
          _historyDebounce?.cancel();
          _historyDebounce = Timer(const Duration(milliseconds: 800), () {
            try { DataSyncBus().emitGlucoseBulk(count: bulkCount); } catch (_) {}
          });
        }
      }
      st['lastTrid'] = last;
      // RACP 재요청 기준(=이미 받은 최대 time offset). 기기의 레코드 식별자와 동일 축이다.
      final int maxOff = records.map((e) => e.offsetMin).reduce((a, b) => a > b ? a : b);
      final int prevOff = (st['lastCgmOffsetMin'] as num?)?.toInt() ?? -1;
      if (maxOff > prevOff) st['lastCgmOffsetMin'] = maxOff;
      await SettingsStorage.save(st);
    } catch (e, s) {
      // 예전에는 `catch (_) {}` 라 타입 오류 한 건에 전체 수집이 조용히 멈췄다.
      unawaited(BleLogService().add('CGMS', 'ingest FAILED: $e'));
      DebugToastBus().show('CGMS: ingest error');
      CrashLogger.record(e, s, source: 'cgms-ingest');
    }
  }

  /// 32비트 범위 내 단조 증가. 16비트 절단(`& 0xFFFF`)은 65,536회 후 0으로 되감겨
  /// 신규 판독을 전부 과거 trid 와 충돌시켰다.
  int _nextTrid(int last) {
    final int n = last + 1;
    return (n >= 0x7FFFFFFF) ? 1 : n;
  }

  /// 세션 시작 시각(epoch ms). 실시간 샘플에서 확정하고 센서(eqsn)별로 영속화한다.
  Future<int?> _resolveSessionBaseMs(
    Map<String, dynamic> st,
    List<_CgmsSample> records, {
    required bool live,
    required String eqsn,
  }) async {
    final String owner = (st['cgmSessionBaseEqsn'] as String? ?? '');
    int? base = (st['cgmSessionBaseMs'] as num?)?.toInt();
    if (base != null && owner != eqsn) base = null; // 센서가 바뀌면 세션도 새로 시작

    // 기준이 이미 있고 이력(백필) 수신이면 그대로 쓴다.
    if (!live && base != null) return base;

    // 기준 산출은 항상 `now - offset`. 이력 수신이어도 기준이 없으면 이 값을 쓴다.
    //
    // 예전에는 이력일 때 `sensorStartAt`(센서 등록 시각)으로 대체했는데, 재연결마다 도는
    // RACP 백필이 **무조건 10초간** 이력 플래그를 켜는 탓에 그 창에 도착한 실시간 패킷이
    // 이력으로 오분류됐다. 등록 시각이 2주 묵은 기기에서 실제로 측정값이 2주 전 날짜로
    // 기록되는 것을 실기기에서 확인했다(SM-F946N, 2026-07-28).
    final int candidate =
        DateTime.now().millisecondsSinceEpoch - records.last.offsetMin * 60000;
    // 재동기 임계를 크게 잡는다. 기준이 조금만 흔들려도 다시 잡으면 저장 시각이 **뒤로 점프**해
    // 차트에 역순 포인트가 생긴다(잠금 18분 검증에서 -250초 점프 15회 관측).
    // 기기 시계 리셋 같은 큰 어긋남만 바로잡고, 소소한 드리프트는 무시한다.
    const int resyncThresholdMs = 30 * 60000;
    final bool newSession = base == null;
    if (base == null || (live && (candidate - base).abs() > resyncThresholdMs)) {
      base = candidate;
      st['cgmSessionBaseMs'] = base;
      st['cgmSessionBaseEqsn'] = eqsn;
      if (newSession) {
        // 새 세션(센서 교체 포함)에서는 기기의 time offset 도 0 부터 다시 시작한다.
        // 이전 세션의 최대 offset 을 남겨두면 `lastCgmOffsetMin` 은 단조 증가만 하므로
        // RACP 백필이 **존재하지 않는 구간**을 요청하게 되어 이력 보충이 조용히 실패한다.
        st['lastCgmOffsetMin'] = -1;
      }
      unawaited(BleLogService().add('CGMS',
          'session base set ${DateTime.fromMillisecondsSinceEpoch(base).toIso8601String()} (live=$live)'));
    }
    return base;
  }

  Future<bool> _subscribeOpsAndStart(String deviceId) async {
    _opsIndSub?.cancel();
    if (!_opsFound || !_opsInd || !_opsWrite) {
      DebugToastBus().show('CGMS: ops char missing/indicate not supported; skip ops start');
      unawaited(BleLogService().add('CGMS', 'skip ops subscribe/start (missing/indicate)'));
      return false;
    }
    final ch = QualifiedCharacteristic(serviceId: serviceCgms, characteristicId: charOpsControl, deviceId: deviceId);
    final completer = Completer<bool>();
    bool acked = false;
    // subscribe indication first
    try {
      _opsIndSub = _nativeBle.subscribeToCharacteristic(ch).listen((data) async {
      // any indication bytes → count and log
      rxCount.value = rxCount.value + 1;
      try {
        final String hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        unawaited(BleLogService().add('CGMS', 'ops ind raw len=${data.length} [${hex}]'));
      } catch (_) {}
      // parse response code (opCode 28, success=1)
      if (data.isNotEmpty) {
        final int op = data[0] & 0xFF;
        if (op == 28 /* response code */) {
          final int rc = (data.length > 2) ? (data[2] & 0xFF) : 0;
          if (rc == 1 /* success */ && !acked) {
            acked = true;
            if (!completer.isCompleted) completer.complete(true);
          }
        } else if (!acked) {
          // fallback: any data marks ack
          acked = true;
          if (!completer.isCompleted) completer.complete(true);
        }
      }
    }, onError: (e, st) {
      if (!completer.isCompleted) completer.complete(false);
    }, onDone: () {
      // do nothing; measurement path will handle retries
    });
    } catch (_) {
      DebugToastBus().show('CGMS: subscribe ops failed (char not found)');
      unawaited(BleLogService().add('CGMS', 'subscribe ops failed'));
      return false;
    }

    // write Start Session opcode (0x1A per CGMS Specific Ops Control Point)
    try {
      await _nativeBle.writeCharacteristicWithResponse(ch, value: const [0x1A]);
      unawaited(BleLogService().add('CGMS', 'ops start write sent'));
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }

    // wait up to 3 seconds for indication
    try {
      final bool ok = await completer.future.timeout(const Duration(seconds: 3), onTimeout: () => false);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> _subscribeRacp(String deviceId) async {
    _racpIndSub?.cancel();
    DebugToastBus().show('CGMS: subscribe RACP');
    unawaited(BleLogService().add('CGMS', 'subscribe RACP'));
    Future<bool> _try(Uuid serviceId) async {
      final ch = QualifiedCharacteristic(serviceId: serviceId, characteristicId: charRacp, deviceId: deviceId);
      try {
        _racpIndSub = _nativeBle.subscribeToCharacteristic(ch).listen((data) async {
      // RACP indication parser (minimal)
      rxCount.value = rxCount.value + 1;
      try {
        final String hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        unawaited(BleLogService().add('CGMS', 'racp ind len=${data.length} [${hex}]'));
      } catch (_) {}
      if (data.isEmpty) return;
      final int opCode = data[0] & 0xFF;
      // 0x05: Number of stored records response, 0x06: General response code
      if (opCode == 0x05) {
        // operator should be 0x00 (null)
        int count = 0;
        final int payload = data.length - 2;
        if (payload == 1) count = data[2] & 0xFF;
        if (payload == 2) count = (data[2] & 0xFF) | ((data[3] & 0xFF) << 8);
        if (payload == 4) count = (data[2] & 0xFF) | ((data[3] & 0xFF) << 8) | ((data[4] & 0xFF) << 16) | ((data[5] & 0xFF) << 24);
        DebugToastBus().show('RACP: count=$count');
        unawaited(BleLogService().add('CGMS', 'racp count=$count'));
      } else if (opCode == 0x06) {
        if (data.length >= 4) {
          final int req = data[2] & 0xFF;
          final int rc = data[3] & 0xFF;
          unawaited(BleLogService().add('CGMS', 'racp rsp req=${req.toRadixString(16)} rc=${rc.toRadixString(16)}'));
          DebugToastBus().show('RACP: rc=0x${rc.toRadixString(16)}');
          // 이력 전송 종료 응답 → 즉시 실시간 모드로 복귀.
          // 타이머(10초)만 믿으면 그 창에 도착한 **실시간** 패킷이 이력으로 오분류된다.
          if (req == 0x01) _endHistoryMode('racp rsp rc=0x${rc.toRadixString(16)}');
        }
      }
      }, onError: (e, st) {
      unawaited(BleLogService().add('CGMS', 'racp ind error'));
      });
        return true;
      } catch (_) {
        return false;
      }
    }
    // prefer standard location (0x1808), fallback to CGMS (0x181F)
    final bool ok = await _try(serviceGlucose) || await _try(serviceCgms);
    if (!ok) {
      DebugToastBus().show('CGMS: subscribe RACP skipped (char not found)');
      unawaited(BleLogService().add('CGMS', 'subscribe RACP skipped'));
    }
  }

  // Public helpers to send common RACP requests using current connection
  Future<void> requestRacpCountAll() async {
    final id = _currentDeviceId;
    if (id == null) { DebugToastBus().show('RACP: not connected'); return; }
    await _racpWrite(id, const [0x04, 0x01]); // Report number of records, Operator: All
  }

  Future<void> requestRacpAllRecords() async {
    final id = _currentDeviceId;
    if (id == null) { DebugToastBus().show('RACP: not connected'); return; }
    await _racpWrite(id, const [0x01, 0x01]); // Report stored records, Operator: All
  }

  Future<void> requestRacpLastRecord() async {
    final id = _currentDeviceId;
    if (id == null) { DebugToastBus().show('RACP: not connected'); return; }
    await _racpWrite(id, const [0x01, 0x06]); // Report stored records, Operator: Last
  }

  /// RACP "Report stored records, Operator ≥, Filter type 0x01".
  /// CGMS(0x181F)에서 filter type 0x01 은 **Time Offset(분)** 이다 — 별도 sequence
  /// number 가 없다. 인자는 앱의 trid 가 아니라 반드시 time offset 이어야 한다.
  Future<void> requestRacpFromTimeOffset(int fromOffsetMinInclusive) async {
    final id = _currentDeviceId;
    if (id == null) { DebugToastBus().show('RACP: not connected'); return; }
    final int v = fromOffsetMinInclusive < 0 ? 0 : (fromOffsetMinInclusive & 0xFFFF);
    await _racpWrite(id, [0x01, 0x03, 0x01, v & 0xFF, (v >> 8) & 0xFF]);
  }

  /// 로컬에 이미 있는 최대 time offset 이후를 기기에 요청(공개 진입점).
  Future<void> requestRacpBackfill() => _racpFillMissingFromLocal();

  Future<void> _racpWrite(String deviceId, List<int> value) async {
    Future<bool> _try(Uuid serviceId) async {
      final ch = QualifiedCharacteristic(serviceId: serviceId, characteristicId: charRacp, deviceId: deviceId);
      try {
        await _nativeBle.writeCharacteristicWithResponse(ch, value: value);
        unawaited(BleLogService().add('CGMS', 'racp write [${value.map((e)=>e.toRadixString(16).padLeft(2,'0')).join(' ')}]'));
        return true;
      } catch (_) { return false; }
    }
    if (await _try(serviceGlucose)) return;
    final ok = await _try(serviceCgms);
    if (!ok) {
      DebugToastBus().show('RACP: write fail');
      unawaited(BleLogService().add('CGMS', 'racp write fail'));
    }
  }

  /// RACP 백필 기준은 **이미 받은 최대 time offset**이다.
  /// 예전에는 로컬 `MAX(trid)`(앱이 만든 카운터)로 요청해, 기기의 레코드 축과
  /// 아무 관계 없는 값을 필터로 보내고 있었다.
  Future<void> _racpFillMissingFromLocal() async {
    try {
      int fromOffset = 0;
      try {
        final st = await SettingsStorage.load();
        fromOffset = ((st['lastCgmOffsetMin'] as num?)?.toInt() ?? -1) + 1;
        if (fromOffset < 0) fromOffset = 0;
      } catch (_) {}
      _historyInProgress = true;
      // 안전망: RACP 종료 응답이 오지 않아도 창을 반드시 닫는다(응답이 오면 즉시 닫힘).
      _historyTimeout?.cancel();
      _historyTimeout = Timer(const Duration(seconds: 10), () => _endHistoryMode('timeout'));
      unawaited(BleLogService().add('CGMS', 'racp backfill from offset=$fromOffset'));
      await requestRacpFromTimeOffset(fromOffset);
    } catch (e) {
      unawaited(BleLogService().add('CGMS', 'racp backfill failed: $e'));
    }
  }

  // legacy direct-write helper removed in favor of _subscribeOpsAndStart()

  Future<bool> _syncTime(String deviceId) async {
    // Try Current Time Service (0x1805 / 0x2A2B). Best-effort.
    try {
      final DateTime now = DateTime.now();
      final int year = now.year;
      final int month = now.month;
      final int day = now.day;
      final int hour = now.hour;
      final int minute = now.minute;
      final int second = now.second;
      final int dow = now.weekday % 7; // 1..7 (Mon..Sun) → 0..6, spec uses 1..7; keep 1..7 with 0 as unknown
      final int frac256 = ((now.millisecond / 1000.0) * 256).round() & 0xFF;
      final int adjust = 0; // no adjustment
      final List<int> payload = <int>[
        year & 0xFF,
        (year >> 8) & 0xFF,
        month & 0xFF,
        day & 0xFF,
        hour & 0xFF,
        minute & 0xFF,
        second & 0xFF,
        (dow == 0 ? 7 : dow) & 0xFF,
        frac256,
        adjust,
      ];
      final ch = QualifiedCharacteristic(serviceId: serviceCurrentTime, characteristicId: charCurrentTime, deviceId: deviceId);
      await _nativeBle.writeCharacteristicWithResponse(ch, value: payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  List<_CgmsSample> _parseCgmsMeasurements(List<int> data) {
    // CGM Measurement (0x2AA7) per nRF Toolbox parser:
    // [size][flags][SFLOAT glucose][uint16 timeOffset][optional status octets][optional trend][optional quality][optional CRC]
    final List<_CgmsSample> out = <_CgmsSample>[];
    if (data.isEmpty) return out;
    int offset = 0;
    while (offset < data.length) {
      if (offset + 1 > data.length) break;
      final int size = data[offset] & 0xFF;
      if (size < 6 || offset + size > data.length) break; // invalid, stop parsing further
      final int flags = data[offset + 1] & 0xFF;
      final bool trendPresent = (flags & 0x01) != 0;
      final bool qualityPresent = (flags & 0x02) != 0;
      final bool warnPresent = (flags & 0x20) != 0;
      final bool calTempPresent = (flags & 0x40) != 0;
      final bool statusPresent = (flags & 0x80) != 0;
      int expect = 6 + (trendPresent ? 2 : 0) + (qualityPresent ? 2 : 0) + (warnPresent ? 1 : 0) + (calTempPresent ? 1 : 0) + (statusPresent ? 1 : 0);
      final bool crcPresent = (size == expect + 2);
      int pos = offset + 2;
      // glucose SFLOAT
      if (pos + 2 > data.length) break;
      final double glucose = _decodeSfloat(data[pos], data[pos + 1]);
      pos += 2;
      // time offset (minutes since session start) — 레코드의 실제 타임스탬프 근거.
      if (pos + 2 > data.length) break;
      final int timeOffset = (data[pos] & 0xFF) | ((data[pos + 1] & 0xFF) << 8);
      pos += 2;
      // skip status octets if present
      if (warnPresent) pos += 1;
      if (calTempPresent) pos += 1;
      if (statusPresent) pos += 1;
      if (trendPresent) pos += 2;
      if (qualityPresent) pos += 2;
      if (crcPresent) pos += 2;
      if (glucose >= 0 && glucose <= 1000) {
        out.add(_CgmsSample(value: glucose, offsetMin: timeOffset));
      }
      offset += size;
    }
    return out;
  }

  double _decodeSfloat(int lo, int hi) {
    final int raw = (lo & 0xFF) | ((hi & 0xFF) << 8);
    int mantissa = raw & 0x0FFF;
    if ((mantissa & 0x0800) != 0) mantissa = mantissa - 0x1000;
    int exponent = (raw >> 12) & 0x0F;
    if ((exponent & 0x08) != 0) exponent = exponent - 0x10;
    return mantissa * pow(10, exponent).toDouble();
  }

  /// [clearPersistentPairing]: true면 `cgms.last_mac`·[BleAutoPairStore] 제거, 자동 재연결 없음.
  /// false면 UI용 last_mac은 유지; 자동 재연결은 [BleAutoPairStore]가 있을 때만 폴링.
  Future<void> disconnect({bool clearPersistentPairing = true}) async {
    _userInitiatedDisconnect = clearPersistentPairing;
    _cancelSignalLossRepeatTimer();
    _cancelNotifyRetryTimer();
    _notifyRetryCount = 0;
    _ar0106SessionReady = false;
    try { await _scanSub?.cancel(); } catch (_) {}
    try { await _notifySub?.cancel(); } catch (_) {}
    try { await _opsIndSub?.cancel(); } catch (_) {}
    try { await _racpIndSub?.cancel(); } catch (_) {}
    try { await _connSub?.cancel(); } catch (_) {}
    _notifySub = null; _opsIndSub = null; _racpIndSub = null; _connSub = null;
    _currentDeviceId = null;
    connectedDeviceId.value = null;
    phase.value = BleConnPhase.off;
    try { DebugToastBus().show('BLE: disconnect requested'); } catch (_) {}
    try { BleLogService().add('BLE', 'disconnect requested'); } catch (_) {}
    _stopAutoReconnectPoller();
    if (clearPersistentPairing) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cgms.last_mac');
        await prefs.remove('cgms.last_name');
        await BleAutoPairStore.clear();
      } catch (_) {}
    } else {
      unawaited(() async {
        if (await BleAutoPairStore.hasPair()) {
          _startAutoReconnectPoller();
        }
      }());
    }
    // 구독 취소로 disconnected 이벤트가 오지 않을 수 있음 — 플래그가 남지 않도록 정리
    unawaited(Future<void>.delayed(const Duration(seconds: 2), () {
      _userInitiatedDisconnect = false;
    }));
  }

  /// Reads BLE Serial Number String (Device Information / 0x2A25) as a best-effort.
  /// Returns null if the characteristic doesn't exist or read fails.
  Future<String?> readSerialNumberString(String deviceId) async {
    try {
      final ch = QualifiedCharacteristic(
        serviceId: serviceDeviceInfo,
        characteristicId: charSerialNumberString,
        deviceId: deviceId,
      );
      final List<int> data = await _nativeBle.readCharacteristic(ch);
      if (data.isEmpty) return null;
      // Serial Number String is usually ASCII/UTF-8 text.
      final String s = String.fromCharCodes(data).replaceAll('\u0000', '').trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }
}

enum BleConnPhase { off, scanning, connecting, connected, opsStarted, timeSynced, notifySubscribed }


