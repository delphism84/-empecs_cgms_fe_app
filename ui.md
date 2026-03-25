## UI Spec — Dashboard & Chart

본 문서는 CGMS 앱의 대시보드(차트 포함) 화면 구성요소와 동작을 개발지시 용도로 정리합니다. 기본(Material) 동작과 단순성을 우선합니다. [TAG]와 [TODO]는 추적을 위한 마커입니다.

### 공통 규칙
- **타이포/크기**: 내부 텍스트 11pt 권장, 중요 숫자/라벨 12–14pt. [TAG:COMMON-TYPO]
- **컴포넌트 높이**: 기본 36px. [TAG:COMMON-HEIGHT]
- **라운드**: 전역 10px. [TAG:COMMON-RADIUS]
- **테마**: 다크/라이트 모두 지원. 불필요한 색상 하드코딩 지양(Material 컬러 우선). [TAG:THEME]
- **네이티브 우선**: 기본 위젯과 제스처를 우선 사용(추가 커스텀은 최소화). [TAG:MATERIAL-FIRST]

## 대시보드 레이아웃 (ChartPage, embedded=false)

- **상단 차트 패널**: 흰 배경, 10px 라운드. 내부에 fl_chart 영역 + 오버레이 UI. [TAG:DASH-CHART-CARD]
- **하단 이벤트 기록 리스트**: `ListView.separated` 형태, 아이템 높이 72px 기준, 구분선 1px. [TAG:DASH-RECORDS]
- **FAB(메모 추가)**: 리스트 우하단 `FloatingActionButton.small` (옵션). [TAG:DASH-FAB]
- **구분선**: 차트/리스트 사이 `Divider(height:1)`. [TAG:DASH-DIVIDER]

동작
- **선택 동기화**: 차트에서 포인트/이벤트 선택 시 리스트 스크롤 동기화(해당 인덱스로 애니메이션 이동). [TAG:SYNC-LIST]
- **배치 평균(와이드 모드)**: 넓은 모드에서 뷰포트 평균 배지 표기. [TAG:WIDE-AVG]

데이터/설정 의존성
- **데이터 소스(포인트)**: `GlucoseLocalRepo.range()` 최근 7일(로컬 선로딩). [TAG:DATA-POINTS]
- **데이터 소스(이벤트)**: `DataService.fetchEvents()` 가능 시 서버 조회, 실패 시 기존 유지. [TAG:DATA-EVENTS]
- **표시 단위**: `SettingsService.getAppSetting().unit` → `mg/dL` 또는 `mmol/L`(factor=1/18). [TAG:UNIT]
- **도트 크기**: `SettingsStorage['chartDotSize']` 1~10 → 반영. [TAG:DOTSIZE]

[TODO:DASH-01] 리스트 아이템 좌측 배지 크기/라인 높이 36px 기준 정규화
[TODO:DASH-02] FAB 노출 조건(권한/상태)에 대한 정책 확정

## 차트 사양 (fl_chart 기반)

엔진/컨테이너
- **엔진**: `fl_chart` `LineChart`. [TAG:CHART-ENGINE]
- **뷰포트 단위**: 시간(ms) 기반 고정. `windowStart`, `windowSize`. [TAG:VIEWPORT]
- **스냅 규칙**: `windowSize`는 3/6/12/24h 중 가장 근접 값으로 스냅. [TAG:SNAP-RANGE]

축/그리드/레이블
- **Y축(좌)**: 왼쪽 오버레이로 50 단위 라벨(10px), 단위는 상단 왼쪽 텍스트로 별도 표기. [TAG:YAXIS-OVERLAY]
- **X축(하단)**: `AM/PM` 12h 라벨, 좌우 가드(1px) 내 라벨 미표시. interval은 tick(1h/3h) 스냅. [TAG:XAXIS-TITLES]
- **그리드**: 수평/수직 라인 색 `#E0E0E0`, 1px. [TAG:GRID]

레인지/라인/포인트
- **In-Range 음영**: 70–180에 `blue(20%)` 배경 밴드. [TAG:RANGE-BAND]
- **경계선**: 70(red, dashed), 180(dark orange, dashed) 수평 라인. [TAG:RANGE-LINES]
- **선 스타일**: 선분은 도트 시각으로 분절(LOW=red, IN=primary, HIGH=dark orange). [TAG:SEGMENT-COLOR]
- **도트 표시**: 기본 숨김, 마지막 포인트/선택 포인트에만 강조(검은 외곽 2px). [TAG:DOTS]

동적 스케일
- **maxY**: 기본 250, 초과 시 10% 헤드룸, 상한 450. [TAG:DYN-MAXY]
- **단위 변환**: 내부 값 × unitFactor 후 렌더. [TAG:UNIT-FACTOR]

오버레이/인터랙션
- **크로스헤어**: 선택 인덱스에 1px 수직선 + 상단 배지(화살표, 값, 시각). [TAG:CROSSHAIR]
- **이벤트 수직선**: 이벤트 위치에 1px 점선(녹색 alpha=0.4). [TAG:EVENT-VLINES]
- **이벤트 배지**: 플롯 상단 30px 지점에 원형 아이콘 배치, 탭 시 뷰포트 센터링 및 선택 연동. [TAG:EVENT-BADGES]
- **상단 날짜 스트립(16px)**: 현재 뷰포트에 포함된 날짜 구간을 일 박스 라벨(월/일)로 좌정렬, 중앙일 bold. [TAG:DATE-STRIP]
- **제스처(1손가락)**: 드래그=수평 이동, 탭=가장 가까운 데이터 선택, 드래그 중 선택 모드=스크럽. [TAG:GESTURE-ONE]
- **제스처(2손가락)**: 핀치 줌(스냅 3/6/12/24h), 이동 시 창 이동; 오른쪽 끝 앵커 유지. [TAG:GESTURE-TWO]

상태/동기화
- **리스트 동기화**: 포인트/이벤트 선택 시 하단 리스트로 스크롤 연동. [TAG:SCROLL-SYNC]
- **와이드 모드**: 좌상단 평균 배지(흰 카드). [TAG:WIDE-BADGE]

[TODO:CHART-01] 상단 배지 폭 측정 후 중앙 정렬 로직 안정화(초기 추정치 144px 제거)
[TODO:CHART-02] unit 텍스트 위치 단일화(좌측 상단 vs Y축 영역) 결정
[TODO:CHART-03] 저/고 범위값(70/180) 설정에서 동적 변경 지원
[TODO:CHART-04] 라벨 폰트 11pt 일괄 정규화(차트/배지/축)
[TODO:CHART-05] 도트 반경 최소/최대 가드(1~10) UI 제공

## 이벤트 기록 리스트 사양

- **아이템 구성**: 좌측 원형 배지(이벤트 타입), 제목=카테고리·시간, 부제=메모. [TAG:RECORD-ITEM]
- **선택 강조**: 선택 이벤트는 배경 `green(8%)`. [TAG:RECORD-SELECT]
- **탭 동작**: 상세 페이지(`EventViewPage`)로 이동(삭제/저장 지원). [TAG:RECORD-NAV]
- **정렬**: 시간 오름차순. [TAG:RECORD-SORT]

카테고리/색/아이콘(정의 고정)
- **카테고리**: Blood glucose, Insulin, Medication, Exercise, Meal, Memo. [TAG:EVENT-CATS]
- **컬러(배지 배경)**: Memo=green, BG=red, Insulin=purple, Medication=teal, Exercise=indigo, Meal=orange. [TAG:EVENT-COLORS]
- **아이콘(Material)**: 물방울/주사기/약/달리기/식사/메모. [TAG:EVENT-ICONS]

[TODO:RECORD-01] 리스트 아이템 타이포 11/13pt 규격 반영 및 일관화
[TODO:RECORD-02] 삭제/저장 후 리스트 즉시 갱신 정책 검토(setState vs 재조회)

## 데이터/동기화 흐름 요약

- **포인트(최근 7일)**: 로컬 DB 선로딩 → 정렬 → 차트 표시 → 동기화 이벤트 수신 시 포인트만 갱신. [TAG:SYNC-POINTS]
- **이벤트**: 서버 조회 성공 시 교체, 실패 시 기존 유지. 일괄 동기화 완료 시 1회 재조회. [TAG:SYNC-EVENTS]
- **외부 포커스**: 외부에서 시간 포커스 변경 시 가장 가까운 포인트로 선택 이동. [TAG:FOCUS-EXTERNAL]

## 센서 섹션(참고: SensorPage)

대시보드 범위는 아니지만 센서 관련 진입점의 요구ID를 함께 정리합니다(요구사항 추적용).

- **New 그룹** 목록 카드: `SC_03_01 Status`, `SC_01_01 Scan & Connect`, `SC_04_01 Serial Number`, `SC_05_01 Start Time`, `SC_07_01 Share Data`, `SC_08_01 How to remove` 등 `DebugBadge(reqId)` 사용. [TAG:SENSOR-LAUNCHERS]
- 각 상세 페이지는 그룹 카드(`_group`) 컴포넌트 사용(타이틀+아이콘 자동 추론). [TAG:SENSOR-GROUP]

[TODO:SENSOR-01] 센서 상세에 대시보드 링크(차트로 이동) 노출 여부 검토

## 요구사항/태그 인덱스

- **요구ID(Sensor)**: `SC_01_01`, `SC_03_01`, `SC_04_01`, `SC_05_01`, `SC_07_01`, `SC_08_01`
- **주요 TAG(차트/대시보드)**: `CHART-ENGINE`, `VIEWPORT`, `SNAP-RANGE`, `YAXIS-OVERLAY`, `XAXIS-TITLES`, `GRID`, `RANGE-BAND`, `RANGE-LINES`, `SEGMENT-COLOR`, `DOTS`, `DYN-MAXY`, `UNIT-FACTOR`, `CROSSHAIR`, `EVENT-VLINES`, `EVENT-BADGES`, `DATE-STRIP`, `GESTURE-ONE`, `GESTURE-TWO`, `SCROLL-SYNC`, `WIDE-AVG`, `WIDE-BADGE`

## 개발 체크리스트(요약)

- [ ] Y축 오버레이 라벨 50단위/11pt 정합 확인 (다크/라이트) [YAXIS-OVERLAY]
- [ ] In-range 밴드/경계선 색상/투명도 매칭 [RANGE-BAND][RANGE-LINES]
- [ ] dotRadius(설정) 반영 및 가드(1~10) [DOTSIZE]
- [ ] 3/6/12/24h 스냅 및 오른쪽 앵커 유지 [SNAP-RANGE]
- [ ] 선택 배지 중앙 정렬 및 폭 측정 보정 [CROSSHAIR]
- [ ] 이벤트 수직선/배지 탭 시 리스트 동기화 [EVENT-VLINES][EVENT-BADGES][SCROLL-SYNC]
- [ ] 단위 전환(mg/dL↔mmol/L) 즉시 반영 [UNIT-FACTOR]

---

참고 코드 위치(핵심)
- `lib/presentation/chart_page/chart_page.dart` — `ChartPage`, `_FlGlucoseChart`, 이벤트/제스처/뷰포트
- `lib/presentation/sensor_page/sensor_page.dart` — 센서 런처 카드 및 상세 그룹 UI


