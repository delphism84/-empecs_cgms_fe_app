# 구현 여부 확인 결과 (ST_01_01 / AR_01_02 / ST_02_01 / ST_03_01 중심)

- 대상: `ST_01_01(언어/단위 적용)`, `AR_01_02(very low 범위 저장)`, `ST_02_01(단위 설정)`, `ST_03_01(Sensors/연결 센서 표시)`
- 확인 방식: **코드 실제 구현 기준**(저장소/적용 로직/엔진 반영 경로 추적) + 최근 수정시간(LastWriteTime)
- 워크스페이스는 git repo가 아니라 “커밋 이력” 대신 파일 수정시간을 사용함

---

## 결론 요약

- **AR_01_02 “설정 범위 저장 안됨”**: 코드상 **구현됨(로컬 캐시 저장 + 엔진 반영 + 서버 best-effort)**  
  - 단, 앱 내에 과거/레거시 화면(`VeryLowAlertPage`)가 남아있어서 “저장 안되는 화면”을 사용 중이면 사용자 입장에서는 미구현처럼 보일 수 있음(라우팅/노출 경로 확인 필요)

- **ST_01_01 / ST_02_01 “언어·단위 적용 안됨”**: 코드상 **구현됨(로컬 저장 + 런타임 적용 + 재실행 유지)**  
  - 언어: `SettingsStorage.language` → `main.dart`에서 startLocale 적용 + `SettingsPage._save()`에서 `context.setLocale()` 호출  
  - 단위: `SettingsStorage.glucoseUnit` 저장 + 차트/대시보드가 로컬 값을 읽어 반영

- **ST_03_01 “연결된 센서 표시 안됨”**: 요구사항의 “설정 메뉴 Sensors”는 서버 목록 기반이고, 별도로 BLE 연결 상태는 `BleService.connectedDeviceId` 등으로 관리됨  
  - 즉 “연결 센서 표시”를 **어느 화면에서** 기대하는지에 따라 판정이 갈림
  - `SC_03_01(SensorStatusPage)`는 현재 **연결 상태/패킷 수 등**을 보여주지만 `deviceId`/`deviceName`은 실데이터 연동이 약함(부분 구현/목업 값 존재)

---

## 1) AR_01_02 (Very Low) · “설정 범위 저장 안됨” 확인

### 구현 경로(현재 앱에서 사용되는 경로)

- Alerts 루트에서 `AR_01_02` 클릭 시 `AlarmTypeDetailPage(type: 'very_low')`로 진입
  - 파일: `lib/presentation/alerts/alerts_root.dart`
  - 파일: `lib/presentation/alarms/alarm_type_detail_page.dart`

- `AlarmTypeDetailPage`는 서버에서 알람 리스트를 가져오고 실패 시 `SettingsStorage.alarmsCache`를 사용, 없으면 로컬 seed를 사용
  - 파일: `lib/presentation/alarms/alarm_type_detail_page.dart`

- 상세 편집/저장은 `AlarmDetailPage`에서 처리
  - 파일: `lib/presentation/settings_page/alarm_detail_page.dart`

### 저장 로직(핵심)

- `AlarmDetailPage._save()` → `_saveLocalCache()` 먼저 수행(**local-first**) 후 서버 업데이트(best-effort)
  - 로컬 저장: `SettingsStorage.save()`로 `alarmsCache`에 type별 overlay 저장
  - 엔진 반영: `AlertEngine().invalidateAlarmsCache()`로 즉시 반영 트리거
  - 엔진 로딩: `AlertEngine`는 `alarmsCache`를 서버 설정과 merge하여 사용
  - 파일: `lib/presentation/settings_page/alarm_detail_page.dart`
  - 파일: `lib/core/utils/alert_engine.dart`

### “저장 안됨”이 실제로 보일 수 있는 케이스(의심 포인트)

- `alerts_root.dart` 하단에 **레거시 화면들**(예: `VeryLowAlertPage`)이 남아있고, 이 화면은 SAVE가 `Navigator.pop`만 함(저장 없음)
  - 만약 앱 내에서 이 레거시 화면이 실제로 노출되고 있다면, 사용자 관점에서 “저장 안됨”이 맞음
  - 따라서 **어떤 화면/라우팅으로 AR_01_02에 진입했는지**가 핵심

---

## 2) ST_01_01 / ST_02_01 · “언어·단위 설정 적용 안됨” 확인

### 저장(재실행 유지)

- `SettingsPage._save()`에서 다음 키들을 `SettingsStorage`에 저장:
  - `language`, `glucoseUnit`, `timeFormat`, 접근성 토글 등
  - 파일: `lib/presentation/settings_page/settings_page.dart`
  - 저장소: `lib/core/utils/settings_storage.dart` (SharedPreferences 기반)

### 런타임 적용(즉시 반영)

- 언어:
  - 앱 시작 시 `SettingsStorage.language`를 읽어 `EasyLocalization.startLocale`로 시작 로케일 적용
  - 실행 중 변경 시 `SettingsPage._save()`에서 `context.setLocale(Locale(lang))` 호출 + `AppSettingsBus.notify()`
  - `main.dart`가 `AppSettingsBus.changed`를 listen하여 `always24h`, 접근성 필터, locale 등을 재적용
  - 파일: `lib/main.dart`

- 단위:
  - `SettingsPage`에서 `glucoseUnit` 저장
  - 차트/대시보드는 `SettingsStorage.glucoseUnit`를 읽어 표시 단위를 변경
  - 파일: `lib/presentation/dashboard/main_dashboard.dart`
  - 파일: `lib/presentation/chart_page/chart_page.dart`, `lib/presentation/chart_page/trend_tab_page.dart`

### 미적용으로 보일 수 있는 케이스(의심 포인트)

- 화면이 서버에서 내려온 `app['unit']`을 우선하여 표시하고, 로컬 저장값과 불일치할 때(오프라인/서버 저장 실패 등) “바뀐 것처럼 안 보임” 가능
  - `SettingsPage._load()`에서 `glucoseUnit = ((app['unit'] ?? '') == 'mmol/L') ? 'mmol' : 'mgdl';` 로 서버값 반영
  - 즉, **로컬에서 바꿔도 다음 로드에서 서버 값으로 덮일 수 있음**(서버 저장 실패 시)

---

## 3) ST_03_01 (Sensors) · “연결된 센서 표시 안됨” 확인

### 구현된 부분

- BLE 연결 자체는 `BleService`가 관리
  - 연결 상태: `BleService.phase`, `BleService.connectedDeviceId`, `BleService.rxCount`
  - 파일: `lib/core/utils/ble_service.dart`

- `SC_03_01` 상태 화면(`SensorStatusPage`)에서 `BleService.phase`, `rxCount`를 사용해 “연결 on/off” 및 패킷 수를 표시
  - 파일: `lib/presentation/sensor_page/sensor_page.dart`

### 부분/미구현으로 보이는 부분

- `SensorStatusPage`의 `deviceName`, `battery`, `rssi` 등은 현재 코드에서 **목업 값**이 섞여 있음(예: `battery=78`, `rssi=-62`, `deviceName='CGMS'`)
- 또한 “Settings > Sensors” 목록은 `SettingsService.listSensors()`(서버) 기반이어서, BLE로 연결된 “현재 센서”와 1:1로 매칭되어 표시되지는 않음
  - 파일: `lib/core/utils/settings_service.dart`
  - 파일: `lib/presentation/settings_page/settings_page.dart` (Sensors 섹션)

---

## 4) 최근 수정 이력(파일 수정시간)

- `lib/presentation/settings_page/alarm_detail_page.dart`: 2026-03-13 (AR_01_02 저장 로직 포함)
- `lib/core/utils/alert_engine.dart`: 2026-03-13 (alarmsCache merge/반영 포함)
- `lib/presentation/settings_page/settings_page.dart`: 2026-03-13 (language/unit 저장 + 런타임 적용 포함)
- `lib/presentation/sensor_page/sensor_page.dart`: 2026-03-13 (SC_03_01 상태 화면 포함)
- `lib/core/utils/settings_storage.dart`: 2026-03-12 (기본키/마이그레이션 포함)

---

## 5) 다음 확인/수정 포인트(권장)

1. **AR_01_02 저장 안됨 재현 시나리오 확인**
   - 실제 앱에서 `VeryLowAlertPage`(레거시)로 진입하는 경로가 남아있는지 제거/차단 필요
2. **단위/언어 “적용 안됨”이 서버 덮어쓰기 때문인지 확인**
   - 오프라인에서 변경 → 재진입 시 서버값으로 되돌아가는지
3. **ST_03_01의 “연결 센서 표시” 요구가 무엇인지 명확화**
   - BLE 현재 연결(실시간) vs 서버 등록 센서 목록(설정) 중 어느 화면/요구인지에 따라 구현 방향이 달라짐

