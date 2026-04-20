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
import 'package:helpcare/core/utils/app_nav.dart';
import 'package:helpcare/core/utils/alert_engine.dart';
import 'package:helpcare/core/utils/warmup_state.dart';
class _CgmsSample {
  _CgmsSample({required this.time, required this.value, required this.trid});
  final DateTime time;
  final double value;
  final int trid;
}


class BleService {
  BleService._internal();
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<List<int>>? _opsIndSub;
  StreamSubscription<List<int>>? _racpIndSub;

  String? _currentDeviceId;
  bool _historyInProgress = false;
  Timer? _historyDebounce;

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
    _scanSub = _ble.scanForDevices(withServices: const [], scanMode: ScanMode.lowLatency).listen(addIfMatch);
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
    _cancelSignalLossRepeatTimer();
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
    _connSub = _ble.connectToDevice(id: deviceId, connectionTimeout: const Duration(seconds: 8)).listen((update) async {
      if (update.connectionState == DeviceConnectionState.connected) {
        _cancelSignalLossRepeatTimer();
        _stopAutoReconnectPoller();
        phase.value = BleConnPhase.connected;
        DebugToastBus().show('BLE: connected');
        unawaited(BleLogService().add('BLE', 'connected'));
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
          // 센서 시작 시각: 재연결마다 무조건 덮어쓰지 않음. 다만 저장된 SN과 불일치하면 새 센서로 간주하고 초기화.
          try {
            final st = await SettingsStorage.load();
            final String eqsn = (st['eqsn'] as String? ?? '').trim();
            final DateTime now = DateTime.now().toUtc();
            final String owner = (st['sensorStartAtEqsn'] as String? ?? '').trim();
            bool dirty = false;
            if (eqsn.isNotEmpty && owner.isNotEmpty && owner.toUpperCase() != eqsn.toUpperCase()) {
              st['sensorStartAt'] = '';
              st['sensorStartAtEqsn'] = '';
              dirty = true;
            }
            final String existingStart = (st['sensorStartAt'] as String? ?? '').trim();
            if (existingStart.isEmpty) {
              st['sensorStartAt'] = now.toIso8601String();
              st['sensorStartAtEqsn'] = eqsn.isNotEmpty ? eqsn : '';
              dirty = true;
              if (eqsn.isNotEmpty) {
                try {
                  await SettingsService().upsertEqStart(serial: eqsn, startAt: now);
                } catch (_) {}
              }
            }
            if (dirty) {
              await SettingsStorage.save(st);
            }
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
          // ACK 성공 여부와 무관하게 Measurement 구독 시도
          await _subscribeGlucose(deviceId);
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
            if (await _hasReconnectTarget()) {
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
    if (phase.value != BleConnPhase.off) {
      // 자동 재연결 중일 때만 잠시 뒤 재시도 — 이미 연결된 상태면 [connectToDevice]에서 타이머 취소됨
      if (phase.value == BleConnPhase.connecting) {
        _armSignalLossChainRetry(const Duration(seconds: 3));
      }
      return;
    }
    final int mins = await _systemSignalLossRepeatMinutes();
    if (phase.value != BleConnPhase.off) {
      if (phase.value == BleConnPhase.connecting) {
        _armSignalLossChainRetry(const Duration(seconds: 3));
      }
      return;
    }
    final int safeMins = mins.clamp(1, 120);
    _signalLossRepeatTimer?.cancel();
    _signalLossRepeatTimer = Timer(Duration(minutes: safeMins), () {
      unawaited(() async {
        if (phase.value != BleConnPhase.off) {
          _cancelSignalLossRepeatTimer();
          return;
        }
        await AlertEngine().notifyBleLinkLost(fromScheduledRepeat: true);
        if (phase.value != BleConnPhase.off) {
          _cancelSignalLossRepeatTimer();
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
      }

      final bool alreadyDone = (st['sc0106WarmupDoneAt'] as String? ?? '').trim().isNotEmpty;
      final bool alreadyActive = st['sc0106WarmupActive'] == true;
      if (alreadyDone || alreadyActive) {
        // If already active/done, just show the warm-up screen.
        if (AppNav.route != '/sc/01/06') await AppNav.goNamed('/sc/01/06');
        return;
      }

      // Start warm-up
      await WarmupState.start(seconds: seconds, eqsn: eqsn);
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
      final List<DiscoveredService> services = await _ble.discoverServices(deviceId);
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

  Future<List<String>> _reconnectDeviceIdCandidates() async {
    final List<String> out = <String>[];
    void add(String? raw) {
      final String t = (raw ?? '').trim();
      if (t.isEmpty) return;
      if (_bleAddressKey(t).isEmpty) return;
      if (!out.any((e) => _bleAddressKey(e) == _bleAddressKey(t))) {
        out.add(t);
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      add(prefs.getString('cgms.last_mac'));
    } catch (_) {}
    try {
      final Map<String, dynamic> s = await SettingsStorage.load();
      add(s['lastScannedQrMac'] as String?);
    } catch (_) {}
    return out;
  }

  Future<bool> _hasReconnectTarget() async {
    final List<String> ids = await _reconnectDeviceIdCandidates();
    return ids.isNotEmpty;
  }

  /// `cgms.last_mac` 우선, 없으면 마지막 QR의 MAC(동일 주소 다른 표기는 한 번만 시도).
  Future<void> tryAutoReconnect() async {
    final List<String> ids = await _reconnectDeviceIdCandidates();
    if (ids.isEmpty) return;
    final String id = ids.first;
    unawaited(BleLogService().add('BLE', 'auto-reconnect -> $id (candidates=${ids.length})'));
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
      if (!await _hasReconnectTarget()) return;
      unawaited(BleLogService().add('BLE', 'auto-reconnect poll'));
      unawaited(tryAutoReconnect());
    });
  }

  void _stopAutoReconnectPoller() {
    _firstReconnectKickTimer?.cancel();
    _firstReconnectKickTimer = null;
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = null;
  }

  Future<void> _subscribeGlucose(String deviceId) async {
    _notifySub?.cancel();
    // short-circuit if characteristic wasn't discovered or is not notifiable
    if (!_measFound || !_measNotify) {
      DebugToastBus().show('CGMS: measurement char missing or not notifiable; skip subscribe');
      unawaited(BleLogService().add('CGMS', 'skip meas subscribe (missing/notifiable)'));
      return;
    }
    final ch = QualifiedCharacteristic(serviceId: serviceCgms, characteristicId: charMeasurement, deviceId: deviceId);
    DebugToastBus().show('CGMS: subscribe notify');
    unawaited(BleLogService().add('CGMS', 'subscribe notify'));
    void _scheduleRetry([String reason = 'unknown']) {
      unawaited(BleLogService().add('CGMS', 'notify stream ended: $reason; retry in 2s'));
      Future.delayed(const Duration(seconds: 2), () {
        if (phase.value != BleConnPhase.off) {
          unawaited(_subscribeGlucose(deviceId));
        }
      });
    }
    try {
      _notifySub = _ble.subscribeToCharacteristic(ch).listen((data) async {
      await _handleCgmsNotifyPacket(data, source: 'ble', silent: _historyInProgress);
      }, onError: (e, st) {
      DebugToastBus().show('CGMS: notify error');
      _scheduleRetry('error');
      }, onDone: () {
      _scheduleRetry('done');
      }, cancelOnError: false);
    } catch (e) {
      // characteristic not found or not discovered yet
      DebugToastBus().show('CGMS: subscribe notify failed (char not found)');
      unawaited(BleLogService().add('CGMS', 'subscribe notify failed'));
      return;
    }
    phase.value = BleConnPhase.notifySubscribed;
    _ar0106SessionReady = true;
  }

  /// 테스트/에뮬레이션용: 실제 BLE notify 수신 경로와 동일한 파서를 호출한다.
  /// - data: CGM Measurement(0x2AA7) notify payload (raw bytes)
  /// - silent: true면(히스토리 동기화처럼) UI 브로드캐스트를 최소화
  Future<void> debugInjectCgmsNotifyBytes(List<int> data, {bool silent = false}) async {
    await _handleCgmsNotifyPacket(data, source: 'emu', silent: silent);
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
      int last = (st['lastTrid'] as int? ?? 0);
      final String eqsn = (st['eqsn'] as String? ?? '');
      int bulkCount = 0;
      for (final _CgmsSample r in records) {
        int usedTrid = r.trid;
        if (usedTrid <= 0 || usedTrid <= last) {
          usedTrid = (last + 1) & 0xFFFF;
        }
        last = usedTrid;
        DebugToastBus().show('CGMS: $source v=${r.value.toStringAsFixed(0)} trid=$usedTrid');
        unawaited(BleLogService().add('CGMS', '$source v=${r.value.toStringAsFixed(0)} trid=$usedTrid'));
        // 캐시/브로드캐스트/업로드는 큐 서비스 단일 경로로 처리 (중복 제거)
        String userId = '';
        try { final st2 = await SettingsStorage.load(); userId = (st2['lastUserId'] as String? ?? ''); } catch (_) {}
        IngestQueueService().enqueueGlucose(r.time, r.value, trid: usedTrid, eqsn: eqsn, userId: userId, silent: silent);
        if (silent) {
          bulkCount++;
          _historyDebounce?.cancel();
          _historyDebounce = Timer(const Duration(milliseconds: 800), () {
            try { DataSyncBus().emitGlucoseBulk(count: bulkCount); } catch (_) {}
          });
        }
      }
      st['lastTrid'] = last;
      await SettingsStorage.save(st);
    } catch (_) {}
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
      _opsIndSub = _ble.subscribeToCharacteristic(ch).listen((data) async {
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
      await _ble.writeCharacteristicWithResponse(ch, value: const [0x1A]);
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
        _racpIndSub = _ble.subscribeToCharacteristic(ch).listen((data) async {
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

  Future<void> requestRacpFromTrid(int fromTridInclusive) async {
    final id = _currentDeviceId;
    if (id == null) { DebugToastBus().show('RACP: not connected'); return; }
    final int lo = fromTridInclusive & 0xFF;
    final int hi = (fromTridInclusive >> 8) & 0xFF;
    // Report stored records, Operator: >=, Filter: Sequence Number (0x01), Param: fromTrid (LE)
    await _racpWrite(id, [0x01, 0x03, 0x01, lo, hi]);
  }

  Future<void> _racpWrite(String deviceId, List<int> value) async {
    Future<bool> _try(Uuid serviceId) async {
      final ch = QualifiedCharacteristic(serviceId: serviceId, characteristicId: charRacp, deviceId: deviceId);
      try {
        await _ble.writeCharacteristicWithResponse(ch, value: value);
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

  Future<void> _racpFillMissingFromLocal() async {
    try {
      final int localMax = await GlucoseLocalRepo().maxTrid();
      final int from = (localMax <= 0) ? 1 : (localMax + 1);
      _historyInProgress = true;
      // safety timeout to end history mode if no data arrives
      Timer(const Duration(seconds: 10), () { _historyInProgress = false; });
      await requestRacpFromTrid(from);
    } catch (_) {}
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
      await _ble.writeCharacteristicWithResponse(ch, value: payload);
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
      // time offset (minutes); not used for timestamp here
      if (pos + 2 > data.length) break;
      // final int timeOffset = (data[pos] & 0xFF) | ((data[pos + 1] & 0xFF) << 8);
      pos += 2;
      // skip status octets if present
      if (warnPresent) pos += 1;
      if (calTempPresent) pos += 1;
      if (statusPresent) pos += 1;
      if (trendPresent) pos += 2;
      if (qualityPresent) pos += 2;
      if (crcPresent) pos += 2;
      if (glucose >= 0 && glucose <= 1000) {
        out.add(_CgmsSample(time: DateTime.now(), value: glucose, trid: 0));
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

  // simulated notify (for random generation): call this with synthetic payload
  void simulateNotify(double value) async {
    final st = await SettingsStorage.load();
    int last = (st['lastTrid'] as int? ?? 0);
    last = (last + 1) & 0xFFFF;
    st['lastTrid'] = last;
    await SettingsStorage.save(st);
    // 시뮬레이션: 곧바로 큐로 인입 (로컬 DB 및 서버 업로드 경로 동일)
    IngestQueueService().enqueueGlucose(DateTime.now(), value, trid: last);
  }

  // removed unused _encodeSfloatPayload helper (not referenced)

  /// [clearPersistentPairing]: true면 `cgms.last_mac` 등을 지우고 자동 재연결 폴링을 시작하지 않음(사용자 Disconnect·로그아웃 등).
  /// false면 BLE 스택만 정리하고 저장 MAC은 유지하며, 필요 시 자동 재연결 폴링을 이어감(부팅 정리·다른 기기로 교체 직전 등).
  Future<void> disconnect({bool clearPersistentPairing = true}) async {
    _userInitiatedDisconnect = clearPersistentPairing;
    _cancelSignalLossRepeatTimer();
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
      } catch (_) {}
    } else {
      _startAutoReconnectPoller();
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
      final List<int> data = await _ble.readCharacteristic(ch);
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


