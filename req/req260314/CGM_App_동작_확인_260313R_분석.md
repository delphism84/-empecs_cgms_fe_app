# CGM App 동작 확인 문서 분석 (260313R)

- **원본**: `CGM App동작 확인_260313R.pptx`
- **분석 도구**: req-analyzer (Node.js)
- **AI 이미지 분석**: Gemini 2.5 Flash Image (25장 분석)
- **생성일**: 2026-03-14

---

## 1. 문서 개요

| 항목 | 내용 |
|------|------|
| 슬라이드 수 | 8 |
| 미디어(이미지) 수 | 22 |
| AI 분석 이미지 | 25 |

---

## 2. 슬라이드별 상세

### 슬라이드 1: 블루투스 연결 – 수동 접속 방식

**추출 텍스트**
- 스크롤화면 이미지 맨 아래에만 **Sensor Connect** 버튼 위치
- 블루투스 연결 방식: **수동 접속 방식**, **QR 스캔으로 자동 접속** 방식
- 디바이스 검색 후 해당 기기 선택 → **Continue** 버튼 확인 없이 메인화면 전환
- **1-1. 수동 접속 방식**

**AI 이미지 분석 요약**

| 이미지 | 화면/요소 | AI 요약 |
|--------|----------|---------|
| image1 | Sensor (SC_02_01) | CGM 앱 Sensor 화면. Usage period, Remaining 11d 0h (valid 14d), Start 2026/03/02 11:08. New 섹션: Status, Scan & Connect, Serial Number, Start Time, Share Data, How to remove. 하단 탭: Home, Trend, Report, Sensor, Alarm, Settings |
| image2 | SC_01_01 Scan & Connect | Start scan, Ready. 검색 기기: EmpecsCGM_DDXX, Empecs Demo CGMS (RSSI·MAC 표시). Connect 버튼. QR & Connect (UM_01_01) |
| image3 | BT Connect Guide | 센서 캡 분리 3단계 안내. 하단 Sensor Connect 버튼 |
| image4 | BT Connect Guide | 센서 부착 가이드 (준비→부착→완료). Sensor Connect 버튼 |
| image5 | SC_01_06_Warm-up | Initial sensor connection warm-up. Warming up 29:58. Started at / Ends at |

**화면 ID 후보**: SC_02_01, SC_01_01, UM_01_01, SC_01_06_Warm-up

---

### 슬라이드 2: QR 스캔으로 자동 접속 – QR 코드 규격

**추출 텍스트**
- **1-2. QR 스캔으로 자동 접속 방식**
- QR 코드 내용 형식: `#1;#2;#3` (세미콜론 구분)
- **QR 코드 항목 표**

| 번호 | 내용 | 기본값 | 설명 |
|------|------|--------|------|
| #1 | ADV 이름 | empecsCGM | 광고명 |
| #2 | ID+MAC | 0xFFFF04AC44111111 | 제조자 ID 0xFFFF(Reserved), MAC 6byte |
| #3 | 일련번호 | 0xC21ZS00101 | 센서 데이터 저장용 |

- 예: `empecsCGM;0xFFFF04AC44111111;0xC21ZS00101` (MAC은 반드시 실제주소)

**AI 이미지 분석**
- QR 코드 이미지: CGM 기기-앱 연동용 정보 인코딩. 스캔 시 디코딩 후 연결 절차 진행

---

### 슬라이드 3: QR 스캔 – 스크롤 다운

**추출 텍스트**
- 1-2. QR 스캔으로 자동 접속 방식
- 스크롤 다운 이미지 삽입
- QR 스캔

**AI 이미지 분석**
- Sensor (SC_02_01), Scan & Connect (SC_01_01), UM_01_01 (센서 부착 가이드), QR & Connect (SC_01_04) 화면 포함
- QR 스캔 흐름: Before QR Scan → Steps(1~3) → Proceed to QR Scan (SC_01_04)

---

### 슬라이드 4: Register Device – SAVE & SYNC 동일 기능

**추출 텍스트**
- **Register Device 클릭** = SC_04_01-Serial Number의 **SAVE & SYNC** 저장기능과 동일 (최초 시리얼번호 DB 저장)
- 디바이스가 BT로 휴대폰 연결 시작
- 연결 시 신호음/진동, 연결 완료 시 **워밍업 페이지**로 자동 이동
- Bluetooth Activation (1-2. QR 스캔 자동 접속)

**AI 이미지 분석**
- QR & Connect: Detected Result(Model, Manufactured, Sample Flag, Serial), Register Device 버튼
- SC_04_01 Serial Number: SAVE & SYNC 저장 기능

---

### 슬라이드 5: Sensor – Start Time 동기화

**추출 텍스트**
- **현재**: Serial Number → QR 스캔 → SAVE & SYNC → Start Time [SAVE] → Start Time 연동 (X)
- **요구**: Start Time을 사용자가 저장하지 않고, **Sensor 연결 후 BT 연결 시각으로 자동 동기화** (O)
- **2-1. Start Time 동기화 관련**

**AI 이미지 분석**
- SC_02_01 Sensor 화면: Usage period, Status, Scan & Connect, Serial Number, Start Time 등
- SC_04_01 Serial Number: 시리얼 번호 입력·등록 화면

---

### 슬라이드 6: Alerts (AR_01_01) – 반영 완료 요청

**추출 텍스트**
- **3-1. Alerts (AR_01_01)** 전체 기능 저장 관련 → 저장 기능 반영 완료
- 반영 완료 버튼 터치 후 화면 전환까지 **3~4초 딜레이** → **빠른 화면 전환 요청**
- **3. Alarm**

---

### 슬라이드 7: 미구현 사항 – High/Low 혈당 라인

**추출 텍스트**
- **High (AR_01_03), Low (AR_01_04)** 각각 고혈당/저혈당 값 입력 시
- 메인 화면 상 고혈당 라인·저혈당 라인이 **입력한 값에 맞게 변경**되어야 함
- **4. 미구현 사항**
  - High (AR_01_03) 설정값에 맞게 혈당 라인 반영
  - Low (AR_01_04) 설정값에 맞게 혈당 라인 반영

**AI 이미지 분석**
- 메인 화면: 현재 혈당(30 mg/dL), 추세, 센서 잔여 일수
- High/Low 라인 반영 미구현

---

### 슬라이드 8: Setting – 기능 저장 미반영 및 개선 요청

**추출 텍스트**
- **3. Setting** 기능 저장 및 반영 안 됨
- 화면 구성은 있으나 범위·버튼 설정이 **저장되지 않음**

| 항목 | 현상 | 상태 |
|------|------|------|
| Language | En/Ar 중 Ar 선택 시 **화면 좌우 반전** | 개선 완료 |
| Time format | 24h/12h 변경 안 됨 (24h만 표시) | 개선 안 됨 |
| Notification | On/Off 저장 안 됨 | 개선 안 됨 |
| Mute all alarms (AR_01_01) | On/Off 저장 안 됨 | 개선 안 됨 |
| Glucose unit | 단위 변경 및 반영 안 됨 (Setting 화면 mg/dL 고정) | 개선 안 됨 |
| Sensors | 동작 안 됨 | 개선 안 됨 |
| Alarms | 동작 안 됨 | 개선 안 됨 |
| Accessibility | 글자 폰트 저장·반영 안 됨 | 개선 안 됨 |

---

## 3. 화면 ID 목록

| ID | 설명 |
|----|------|
| SC_01_01 | Scan & Connect |
| SC_01_04 | Serial Number / QR 스캔 |
| SC_01_06_Warm-up | Initial sensor connection warm-up |
| SC_02_01 | Sensor |
| SC_04_01 | Serial Number (SAVE & SYNC) |
| AR_01_01 | Alerts |
| AR_01_03 | High (고혈당) |
| AR_01_04 | Low (저혈당) |
| UM_01_01 | Sensor attachment guide / QR Scan 이전 가이드 |

---

## 4. 요구사항 및 개선 항목 정리

---

## 4-1. 구현 푸시 정책 (적용 기준)

| 구분 | 정책 | 비고 |
|------|------|------|
| **현재것 푸시** | 확실한 것(§5) → 구현 반영/배포 대상으로 푸시 | Start Time 자동 동기화, 고/저 라인 반영, AR_01_01 화면 전환 |
| **미구현** | 다시 구현 | High (AR_01_03), Low (AR_01_04) 설정값 → 메인 화면 혈당 라인 반영 |
| **미확실** | 구현 코드가 없으면 구현 | 아래 §5 미확실 항목별로 코드 존재 시 유지, 없으면 구현 |

---

## 5. 구현 우선순위 분류

### ✅ 확실한 것 → 구현 진행

| # | 항목 | 요구 내용 |
|---|------|-----------|
| 1 | **Start Time 자동 동기화** | Sensor 연결 후 BT 연결 시각으로 Start Time 자동 설정 (사용자 수동 저장 불필요) |
| 2 | **고/저혈당 라인 반영** | High (AR_01_03), Low (AR_01_04) 설정값을 메인 화면 혈당 차트에 기준선으로 반영 |
| 3 | **AR_01_01 화면 전환 속도** | 반영 완료 버튼 터치 후 3~4초 딜레이 → 빠른 화면 전환 (2초 이내 권장) |

---

### ⚠️ 미확실 / 확인 필요 → 보류

| # | 항목 | 확인 필요 사유 |
|---|------|----------------|
| 1 | **Time format (24h/12h)** | impl_check: 코드상 저장·적용 경로 존재. 실제 미반영이 서버 덮어쓰기인지, 특정 화면만인지 확인 필요 |
| 2 | **Notification On/Off 저장** | 어느 설정 화면의 어떤 토글인지(AR_01_01 vs 별도 Notification 메뉴) 범위 확인 필요 |
| 3 | **Mute all alarms (AR_01_01) 저장** | AR_01_01 저장 로직은 구현됨(impl_check). 미반영 시 레거시 화면 경로·라우팅 확인 필요 |
| 4 | **Glucose unit 및 Setting 화면 표시** | 단위 변경은 적용됨. “Setting 화면에 mg/dL 고정”이 라벨 텍스트만인지 전체 미반영인지 확인 필요 |
| 5 | **Sensors 동작** | “동작 안 됨”이 BLE 연결 센서 표시인지, 서버 목록인지, 어느 화면(SC_03_01 vs Settings)인지 명확화 필요 |
| 6 | **Alarms 동작** | “동작 안 됨”이 알람 발생·저장·표시 중 어느 단계인지 확인 필요 |
| 7 | **Accessibility 글자 폰트 저장** | 저장 키·적용 경로 존재 여부, 미반영 재현 경로 확인 필요 |

#### 미확실 항목별 구현 코드·연결 메뉴 검토

| # | 항목 | 구현된 코드 | 연결된 메뉴/화면 |
|---|------|-------------|------------------|
| 1 | **Time format (24h/12h)** | `SettingsStorage`: `timeFormat` (default `'24h'`). `main.dart`: `_always24h` ← `st['timeFormat']=='24h'`, `MediaQuery.alwaysUse24HourFormat`. `settings_page.dart`: General 카드 내 "Time format" 행 → `_showSelectSheet('24h'/'12h')` → `_save()` → 로컬+BE. | **Settings** 탭 → Settings 루트 → **General** (Language, Region, Notifications) → **Time format** (24h/12h 선택). 적용: 앱 전역 `MediaQuery.alwaysUse24HourFormat`. |
| 2 | **Notification On/Off 저장** | `SettingsStorage`: `notificationsEnabled`. `notification_service.dart`: `setEnabled(notificationsEnabled)` 초기화·변경 시 호출. `settings_page.dart`: General 카드 내 "Notifications" 토글 → `_save()` → `NotificationService().setEnabled(notificationsEnabled)`. | **Settings** 탭 → **General** → **Notifications** 토글. 별도 "Notification 메뉴"는 없음(알림 목록 화면 `NotificationScreen`은 통계/홈 등에서 링크만 있고, On/Off 설정과 무관). |
| 3 | **Mute all alarms (AR_01_01)** | `SettingsStorage`: `alarmsMuteAll`. `alert_engine.dart`: 알람 발생 시 `st['alarmsMuteAll']==true`이면 소리/진동 비활성. `settings_page.dart`: General → "Mute all alarms (AR_01_01)" 토글. `ar_01_01_mute_all_screen.dart`: 전용 화면에서도 동일 키 저장. | **Settings** → General → **Mute all alarms (AR_01_01)** 토글. **Alerts** 탭(AR_01_01) → "Mute all alarms" 행 터치 시 `Ar0101MuteAllScreen` (동일 설정). |
| 4 | **Glucose unit / Setting 표시** | `SettingsStorage`: `glucoseUnit` ('mgdl'\|'mmol'). `main_dashboard.dart`, `chart_page.dart`, `trend_tab_page.dart`: `st['glucoseUnit']` 읽어 `_unit`/`_unitFactor` 적용. `settings_page.dart`: Units 카드 → "Glucose unit" 선택 시 로컬+BE 저장. | **Settings** → **Units** → **Glucose unit** (mg/dL / mmol/L). Setting 화면 내 라벨도 `glucoseUnit== 'mgdl' ? 'mg/dL' : 'mmol/L'`로 동적 표시. |
| 5 | **Sensors 동작** | `SettingsService.listSensors()`: 로컬 `sensorsCache` 반환. Sensor **목록/등록** UI는 **Sensor 탭**에서만 사용(SC_02_01). `sensor_page.dart`: Status → `SensorStatusPage` (SC_03_01, BLE 연결 상태·배터리·웜업). Settings에는 Sensors 패널 없음(req_remove에 따라 제거됨). | **Sensor** 탭(SC_02_01) → 카드/등록·QR·수동 SN. 동일 탭 내 **Status** → SC_03_01(연결 상태). "Sensors 동작 안 됨"은 **SC_03_01** 또는 **로컬 sensorsCache 목록** 중 어느 쪽인지 구분 필요. |
| 6 | **Alarms 동작** | **저장**: `alarm_detail_page.dart` 로컬 캐시 → `SettingsService.updateAlarm`(로컬+BE). **표시**: Settings → Alarms 카드 목록, Alerts 탭(AR_01_01) 목록. **발생**: `alert_engine.dart`가 `listAlarms()` 후 threshold 평가 → `NotificationService.showAlert`. | **Alerts** 탭(AR_01_01): Very Low/High/Low/Rate/System 각 행 → `AlarmTypeDetailPage` 또는 `Ar0101MuteAllScreen`. **Settings** → Alarms 카드: 동일 목록에서 토글/상세. "동작 안 됨"은 발생/저장/표시 중 어디인지 확인 필요. |
| 7 | **Accessibility 글자 폰트 저장** | `SettingsStorage`: `accHighContrast`, `accLargerFont`, `accColorblind`. `main.dart`: `_textScale = kGlobalTextScale * (accLargerFont ? 1.20 : 1.0)`, `MediaQuery.textScaler`; `_applyAccessibilityFilters`에서 `_accColorblind`(색상 필터), `_accHighContrast`(대비 필터). `AppSettingsBus.changed` 시 재로드. | **Settings** → **Accessibility** → **High contrast**, **Larger font**, **Color blind mode** 토글. 저장 즉시 `AppSettingsBus.notify()` → 앱 전역 필터/텍스트 스케일 재적용. (글자 "폰트"는 Larger font = 텍스트 스케일 1.2배.) |

**미확실 항목 구현 기준**: 위 항목별로 앱/백엔드에 구현 코드가 없으면 구현한다. 이미 저장·적용 경로가 있으면 동작 확인 후 보류 가능.

**백엔드 반영 (이번 푸시)**  
- 미구현: `GET /api/settings/chart-thresholds` — High/Low 알람 threshold 반환 → 앱 메인 차트에 고/저 라인 그리기용.  
- 미확실: `AppSetting`에 `timeFormat`(24h/12h), `alarmsMuteAll` 필드 추가 및 `PUT /api/settings/app`에서 저장.

---

## 5-1. QA 검수·캡처 진행

- **직접 검수 및 캡처**: 에이전트는 로컬호스트 접속이 불가하므로, **로컬에서** 아래 체크리스트대로 진행한다.
- **체크리스트·캡처 저장**: [`req/req260314/QA_검수_캡처_체크리스트.md`](QA_검수_캡처_체크리스트.md)
- **실행**: `flutter run -d chrome` 또는 `flutter run -d web-server --web-port=8080` 후 브라우저에서 접속.
- **캡처 저장 경로**: `req/req260314/qa_captures/` (체크리스트 표에 명시된 파일명으로 저장).

---

## 6. 분석 도구 사용법

```bash
cd tools/req-analyzer
node src/cli.js "req/req260314/CGM App동작 확인_260313R.pptx" --out "req/req260314/_analysis" --ai --ai-max-images 80
```

출력: `req-extracted.json`, `req-analysis.md`, `req-ai-cache.json`
