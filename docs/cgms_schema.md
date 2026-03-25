## CGMS 앱 스키마 문서 (cgms_schema.md)

문서 버전: 2025-09-19 (rev. A)
출처: (디앤에스)CGMS_앱_기능구성도_(25.09.11) (1).csv, (디앤에스)CGMS_앱_기능구성도_(25.09.11) (1).htm, [디앤에스]CGMS_앱_스토리보드 250818.html

### 1) 화면 ID 규칙/카테고리
- LO: 로그인/회원가입
- SC: 센서 등록/관리
- ST: 설정(단위/목표 등)
- GU: 메인/홈 상태 요소
- TG: 트렌드 그래프
- RP: 리포트/분석 요약
- AR: 알림/경보
- ME: 메모/이벤트 입력
- MAIN_*: 메인 허브/앱 내 알림 등

### 2) 화면 레지스트리 요약
| 화면ID | 화면명 | 카테고리 | 설명 | 출처 |
|---|---|---|---|---|
| LO_01_01 | 로그인 페이지 | LO | SNS 로그인 선택(구글/애플/카카오) | CSV, 스토리보드 |
| LO_01_02 | Google 로그인 | LO | 구글 계정 연동 | CSV, 스토리보드 |
| LO_01_03 | Apple 로그인 | LO | 애플 계정 연동 | CSV, 스토리보드 |
| LO_01_04 | 카카오 로그인 | LO | 카카오 계정 연동 | CSV, 스토리보드 |
| LO_01_05 | 간편(임시비번) 로그인 | LO | 4자리/간편 로그인 | CSV, 스토리보드 |
| LO_01_06 | 생체인증 로그인 | LO | FaceID/TouchID/지문 | CSV, 스토리보드 |
| LO_01_07 | 센서 등록 여부 | LO | 기존 센서 여부 확인 및 등록 시작 | 확정(센서등록) |
| LO_01_08 | 둘러보기 모드 | LO | 비로그인 제한 모드 | CSV |
| LO_02_01 | 회원가입 안내 | LO | 가입 플로우 안내 | CSV, 스토리보드 |
| LO_02_02 | 약관동의 | LO | 약관·개인정보 동의 | CSV, 스토리보드 |
| LO_02_03 | 본인인증 | LO | 문자코드/타이머 | CSV, 스토리보드 |
| LO_02_04 | 회원 정보 입력 | LO | ID/비번/연락처 | CSV, 스토리보드 |
| LO_02_05 | 회원가입 완료 | LO | 완료 메시지 | CSV, 스토리보드 |
| LO_02_06 | 생체인증 등록 | LO | 이후 로그인 간소화 | CSV, 스토리보드 |
| LO_03_01 | 임시비번 초기화/비밀번호 찾기 | LO | 비번 재설정 | CSV |
| SC_01_03 | NFC 스캔 | SC | 태그 스캔 | CSV, 스토리보드 |
| SC_01_04 | QR 스캔 | SC | 코드 스캔 | CSV, 스토리보드 |
| SC_01_05 | 일련번호 입력 | SC | 수동 등록 | CSV, 스토리보드 |
| SC_01_06 | 센서 웜업 | SC | 30분 카운트다운 | CSV, 스토리보드 |
| SC_02_01 | 사용기간/유효기간 | SC | 남은 기간 표시 | CSV, 스토리보드 |
| SC_03_01 | 연결 상태 | SC | 통신/상태 확인(타일 아님) | 확정(상태) |
| SC_04_01 | 일련번호 표시 | SC | 현재 센서 ID | CSV, 스토리보드 |
| SC_05_01 | 데이터 시간(시작/범위) | SC | 일/주/월/시간 | CSV, 스토리보드 |
| SC_06_01 | NFC 재연결 | SC | 교체/재연결 | CSV, 스토리보드 |
| SC_06_02 | QR 재연결 | SC | 교체/재연결 | CSV, 스토리보드 |
| SC_07_01 | 수집 문제 안내 | SC | 수집/전송 이슈 가이드 | CSV |
| ST_01_01 | 단위/목표 범위 설정 | ST | mg/dL, mmol/L | CSV |
| ME_01_01 | 이벤트/메모 입력 | ME | 운동/수면/식사/약물 등 | CSV, 스토리보드 |
| GU_01_01 | 현재 혈당 | GU | 실시간 수치/업데이트 | CSV, 스토리보드 |
| GU_01_02 | 타임라인/변화량 | GU | 중요 이벤트/변화량 | CSV, 스토리보드 |
| GU_01_03 | 상태/색상 표시 | GU | 목표범위/상태 | CSV, 스토리보드 |
| TG_01_01 | 일간 트렌드(세로) | TG | 3/6/12/24시간 | CSV, 스토리보드 |
| TG_01_02 | 기간 트렌드(가로) | TG | 3/7/14/30일, 분석 | CSV, 스토리보드 |
| RP_01_01 | 리포트/통계(대시보드 하위) | RP | 목표범위/평균/표준편차 요약 | 통합(XX_01_01→RP_01_01) |
| AR_01_01 | 알림 기본/방식 설정 | AR | 무음·방해금지 등 | CSV, 스토리보드 |
| AR_01_02 | 매우 낮은 혈당 알림 | AR | 저혈당 하위 별도 알림(임계/사운드/반복) | 확정 |
| AR_01_03 | 고혈당 알림 | AR | 임계/반복 | CSV, 스토리보드 |
| AR_01_04 | 저혈당 알림 | AR | 임계/반복 | CSV, 스토리보드 |
| AR_01_05 | 급격변화 알림 | AR | 변화율 임계 | CSV, 스토리보드 |
| AR_01_06 | 신호 손실 알림 | AR | 반복/확인 주기 | CSV, 스토리보드 |
| AR_01_07 | 기타 시스템 알림 | AR | 배터리/저장공간 등 | CSV |
| AR_01_08 | 잠금화면/리마인더 | AR | 잠금 알림/리마인더 | CSV, 스토리보드 |
| MAIN_DASHBOARD | 메인 홈(대시보드) | MAIN | 혈당+그래프+상태 허브 | 표준명 확정 |

참고: 일부 명칭은 인코딩/문맥 차이로 상이함. 하단 MISSED/CONFLICT 참조. 스토리보드 전용 `MAIN_ALERT/DETAIL_VIEW/USER_ACTION/EMERGENCY`는 미사용(SKIP).

### 3) 내비게이션 스키마 (버튼/액션 → 이동 화면)
형식: From(ScreenID) · 버튼/액션 · 조건(있으면) · To(ScreenID) · 전이 방식

#### 로그인/회원가입
- LO_01_01 · [Google로 계속] ·  · LO_01_02 · push
- LO_01_01 · [Apple로 계속] ·  · LO_01_03 · push
- LO_01_01 · [카카오로 계속] ·  · LO_01_04 · push
- LO_01_01 · [비밀번호 찾기] ·  · LO_03_01 · modal/push
- LO_01_01 · [둘러보기] ·  · LO_01_08 · push

- LO_01_02 · [계정 연동 성공] · 기존 회원 · LO_01_05 또는 LO_01_06 · replace
- LO_01_02 · [계정 연동 성공] · 신규 회원 · LO_02_01 · push
- LO_01_03 · [계정 연동 성공] · 기존 회원 · LO_01_05 또는 LO_01_06 · replace
- LO_01_03 · [계정 연동 성공] · 신규 회원 · LO_02_01 · push
- LO_01_04 · [계정 연동 성공] · 기존 회원 · LO_01_05 또는 LO_01_06 · replace
- LO_01_04 · [계정 연동 성공] · 신규 회원 · LO_02_01 · push

- LO_01_05 · [확인/로그인] ·  · MAIN_DASHBOARD · replace
- LO_01_06 · [인증 성공] ·  · MAIN_DASHBOARD · replace

- LO_02_01 · [시작/다음] ·  · LO_02_02 · push
- LO_02_02 · [동의하고 계속] ·  · LO_02_03 · push
- LO_02_03 · [인증 완료] ·  · LO_02_04 · push
- LO_02_04 · [가입 완료] ·  · LO_02_05 · replace
- LO_02_05 · [생체인증 등록] ·  · LO_02_06 · push
- LO_02_05 · [나중에 하기] ·  · (센서 등록 시작) LO_01_07 또는 SC_01_03 · push
- LO_02_06 · [등록 완료] ·  · (센서 등록 시작) LO_01_07 또는 SC_01_03 · push

#### 센서 등록/관리
- LO_01_07 · [센서 등록하기] ·  · (등록 방법 선택) → SC_01_03/SC_01_04/SC_01_05 · push
- LO_01_07 · [나중에] ·  · MAIN_DASHBOARD(제한 모드) · replace

- SC_01_03 · [스캔 성공] ·  · SC_01_06 · replace
- SC_01_03 · [스캔 실패] ·  · SC_01_05 · push
- SC_01_04 · [스캔 성공] ·  · SC_01_06 · replace
- SC_01_04 · [스캔 실패] ·  · SC_01_05 · push
- SC_01_05 · [일련번호 등록] ·  · SC_01_06 · replace
- SC_01_06 · [웜업 완료] ·  · MAIN_DASHBOARD · replace

- SC_02_01 · [연결 상세] ·  · SC_03_01 · push
- SC_02_01 · [재연결(NFC)] ·  · SC_06_01 · push
- SC_02_01 · [재연결(QR)] ·  · SC_06_02 · push

#### 메인/홈
- MAIN_DASHBOARD · [현재 혈당 카드] ·  · GU_01_01 · push
- MAIN_DASHBOARD · [트렌드 그래프] ·  · TG_01_01 · push
- MAIN_DASHBOARD · [상세 그래프] ·  · TG_01_02 · push
- MAIN_DASHBOARD · [통계/리포트] ·  · RP_01_01 · push
- MAIN_DASHBOARD · [알람 설정] ·  · AR_01_01 · push
- MAIN_DASHBOARD · [메모 추가] ·  · ME_01_01 · modal/push
- MAIN_DASHBOARD · [센서 관리] ·  · SC_02_01 · push

#### 그래프/분석
- TG_01_01 · [가로모드/상세] ·  · TG_01_02 · push
- TG_01_02 · [기간 선택 3/7/14/30일] ·  · TG_01_02(상태 전환) · state
- XX_01_01 · [리포트로 이동] ·  · RP_01_01 · push

#### 알림/경보
- AR_01_01 · [저혈당 설정] ·  · AR_01_04 · push
- AR_01_01 · [고혈당 설정] ·  · AR_01_03 · push
- AR_01_01 · [급격변화 설정] ·  · AR_01_05 · push
- AR_01_01 · [신호 손실 설정] ·  · AR_01_06 · push
- AR_01_01 · [매우 낮은 혈당] ·  · AR_01_02 · push
- AR_01_01 · [잠금화면 알림] ·  · AR_01_08 · push
- AR_01_04/AR_01_03/AR_01_05/AR_01_06 · [저장/뒤로] ·  · AR_01_01 · back
 - AR_01_02 · [저장/뒤로] ·  · AR_01_01 · back

#### 응급/알림 흐름
- (이상 감지) · [잠금화면 표시] ·  · AR_01_08 · system
- AR_01_08 · [열기/앱 포그라운드] ·  · MAIN_DASHBOARD · replace

### 4) 상태/가드 요약
- 게스트(LO_01_08): 주요 기능 제한, 로그인 유도 UI 노출
- 센서 웜업(SC_01_06): 웜업 완료 전 TG/GU 일부 기능 제한
- 생체 등록(LO_02_06): 차회 로그인에 LO_01_06 우선 경로 제공

### 5) MISSED 목록 (확인 필요)
1. 둘러보기(LO_01_08) 경로/권한 범위
2. Settings(설정) 세부 페이지 ID/내비게이션 정의
3. 리포트 진입 버튼 위치/라벨(대시보드, 그래프, 홈 어디서 노출할지)

### 6) 구현 메모(개발 참고)
- 전이 타입: push(새 화면), replace(스택 교체), modal(오버레이), back(이전), state(동일 화면 상태 전환), system(OS 레벨)
- 카테고리별 공통 헤더: 메인에서 각 카테고리 진입 시 상단 탭/백버튼 일관성 유지
- 장애/권한: 알림 권한 부재 시 AR 경로 진입에 가드 추가, NFC/카메라 권한 체크는 SC_01_03/SC_01_04 진입 직전 수행

### 7) 하단 탭 구성(HTML 매핑 포함)
- Home → `MAIN_DASHBOARD` → prototypes/main.html
- Chart → `TG_01_01`(기본) → prototypes/charts.html · 세부 `TG_01_02` → prototypes/trendview.html
- Stats → `RP_01_01` → prototypes/statistics.html
- Sensor → `SC_02_01` → prototypes/sensor.html
- Alerts → `AR_01_01` → prototypes/alerts.html
- Setting → Settings 루트 → prototypes/settings.html

탭 클릭 시 해당 루트 화면으로 이동하며, 각 화면 내 세부 전이는 본 스키마의 내비게이션 규칙을 따른다.

### 8) Flutter 네비게이션/탭 구조(디자인 기준)
- 하단 공통 탭 모듈: BottomNavigationBar(6 tabs)
- 라우트 이름
  - /home → MAIN_DASHBOARD
  - /chart → TG_01_01 (세부는 같은 스택 내 상태 전환으로 TG_01_02)
  - /stats → RP_01_01
  - /sensor → SC_02_01
  - /alerts → AR_01_01
  - /settings → Settings 루트
- 전이 원칙
  - 탭 전환: replace(스택 초기화) 또는 탭 전용 스택 유지 정책 중 하나 선택(디폴트: 탭별 스택 유지)
  - 화면 내 세부 이동: push/back, modal(state) 규칙 준수
  - 시스템 이벤트(알림 등): 앱 포그라운드 시 /home으로 복귀(AR_01_08 → MAIN_DASHBOARD)

페이지 구성 요약
- HomePage(대시보드) · ChartPage · StatsPage · SensorPage · AlertsPage · SettingsPage

### 9) 대시보드(UI) 상세 스펙(main.html 기준, 요구사항 우선)
1) 상단 바
   - 좌측: 사용자명
   - 중앙: CGMS 명칭(앱 타이틀/브랜드)
   - 우측: BLE 상태 아이콘(연결/스캔/오류)
2) 메인 카드(orb 형태)
   - 실시간 혈당값, 추세 화살표, 변화율
   - 당일 min / max / avg 요약 수치 동시 표기
3) 차트 영역(가로 확장)
   - main.html의 그래프 레이아웃 사용
   - 터치 시 TG_01_02(가로 상세)로 확장 전이 가능
4) 하단 이벤트 리스트
   - 최신 이벤트(운동/식사/약물/수면/메모) 타임라인
   - 항목 클릭 시 ME_01_01 편집 또는 관련 상세로 이동
5) 하단 탭
   - 공통 모듈로 모든 페이지에서 동일 노출

주의: HTML 프로토타입은 V1.0이며, 요구사항 정의서는 최종 V2.0로 간주한다. 충돌 시 요구사항(V2.0)을 우선 적용한다.

### 10) Settings 상세 트리 및 이동 규칙
루트: prototypes/settings.html
- ST_01_01 Localization
  - Language(언어) 선택
  - Region(지역) 선택
  - Auto-detect region 스위치(On 시 지역/단위 UI 잠금 및 단위 자동 지정)
- LO_01_08 Guest mode
  - 게스트 모드 토글(데이터 동기화/클라우드 제한 안내)
- Units
  - Glucose unit: mg/dL | mmol/L
  - Time format: 24h | 12h
- SC_07_01 Data sharing
  - Range: 1/3/7/14/30 days | custom(기간 직접 선택)
  - 가족 공유, 헬스앱 연동 토글
  - Save/Revoke 액션
- Accessibility
  - High contrast / Larger font / Colorblind palette 토글
- Debug 링크 → prototypes/debug.html

이동 규칙(설정 내부)
- /settings → Settings 루트 표시
- 항목 클릭/토글은 같은 페이지 내 상태(state) 변경으로 처리, 별도 화면 전이는 없음
- 단, Data sharing의 Save/Revoke는 저장 이벤트 트리거만 발생(네비 변경 없음)



### 11) Settings 영속화 스펙(localStorage)

- 저장소 키: `cgms.settings`
- 저장 시점: 모든 컨트롤 변경 시 즉시 자동 저장(autosave). 별도 제출 없음.
- 복원 시점: `settings.html` 로드 시 1회 복원 후, UI 종속 규칙을 즉시 반영.
- 데이터 스키마(JSON):
  - `language` · select(`langSelect`) · 값: `en|ko|ja`
  - `region` · select(`regionSelect`) · 값: `KR|US|GB|CA|EU`
  - `autoRegion` · switch(`autoRegion`) · boolean
  - `guestMode` · switch(`guestMode`) · boolean
  - `glucoseUnit` · select(`glucoseUnitSelect`) · 값: `mgdl|mmol`
  - `timeFormat` · select(`timeFormatSelect`) · 값: `24h|12h`
  - `shareConsent` · checkbox(`shareConsent`) · boolean
  - `shareRange` · select(`shareRange`) · 값: `1|3|7|14|30|custom`
  - `shareFrom` · input[type=date](`shareFrom`) · ISO `YYYY-MM-DD` 문자열 또는 빈 문자열
  - `shareTo` · input[type=date](`shareTo`) · ISO `YYYY-MM-DD` 문자열 또는 빈 문자열
  - `shareFamily` · checkbox(`shareFamily`) · boolean
  - `shareHealth` · checkbox(`shareHealth`) · boolean
  - `accHighContrast` · switch(`accHighContrast`) · boolean
  - `accLargerFont` · switch(`accLargerFont`) · boolean
  - `accColorblind` · switch(`accColorblind`) · boolean

- UI 종속/비즈니스 규칙:
  - `autoRegion = true`인 경우 `regionSelect`, `glucoseUnitSelect`는 비활성화되고, 단위는 지역에 따라 자동 지정.
    - 매핑 규칙: `US, KR → mgdl`, 기타 → `mmol`
  - `shareRange = custom`인 경우만 `shareFrom`, `shareTo` 입력을 표시. 그 외 구간에서는 숨김 처리.
  - `shareConsent = false`이면 [Save] 버튼 비활성화. 단, autosave는 항목 변경 즉시 수행됨.

- 마이그레이션:
  - 저장 스키마에 신규 필드가 추가되는 경우, 복원 시 없는 키는 합리적 기본값으로 채움.
  - 잘못된 값이 복원된 경우(검증 실패)에는 기본값으로 대체하고 즉시 재저장.

- 기본값(Default):
  - `language: 'en'`, `region: 'KR'`, `autoRegion: true`, `guestMode: false`
  - `glucoseUnit: 'mgdl'`, `timeFormat: '24h'`
  - `shareConsent: false`, `shareRange: '7'`, `shareFrom: ''`, `shareTo: ''`, `shareFamily: false`, `shareHealth: false`
  - `accHighContrast: false`, `accLargerFont: false`, `accColorblind: false`

- **설정 저장 정책(앱 구현)**:
  - **모든 설정 기본 로컬 저장**: 앱 설정·알람·센서 목록은 SharedPreferences(SettingsStorage)에 저장. 읽기 시 항상 로컬만 사용.
  - **BE는 로컬 성공 후 업로드용**: 저장 시 1) 로컬에 먼저 반영, 2) 그 다음 BE에 PUT/POST. BE 실패 시 로컬 값은 유지.
  - **BE 실패 시 폴백 없음**: 서버 요청 실패 시 로컬을 서버 값으로 덮어쓰지 않음. 재시도/토스트 등은 별도 정책.

### 12) 차트 터치/제스처 고도화 스펙

범위: `TG_01_01`(일간·세로) · `TG_01_02`(기간·가로), 대시보드 미니 차트(메인 카드 하위) 포함. 구현 기준은 요구사항 우선, HTML 프로토타입(`prototypes/charts.html`, `prototypes/trendview.html`)은 동작 참고.

1) 공통 제스처(모든 차트)
- 단일 탭: 최근 샘플로 스냅 이동 및 포커스 토글(표시/숨김)
- 길게 누름(>250ms): 스크럽 모드 진입(크로스헤어+툴팁 고정) · 손가락 이동으로 시점 추적
- 드래그(스크럽 모드): 시간축 따라 이동, 근접 샘플로 스냅
- 더블탭: 줌 토글(최근 레벨 ↔ 전체 보기)
- 핀치 줌: 시간축 확대/축소(아래 3) 참조)
- 두 손가락 드래그: 팬(확대 상태에서만)
- 롱프레스 종료: 손가락 떼면 스크럽 모드 해제(사용자 설정으로 유지 가능)

2) 크로스헤어/툴팁(공통 UI)
- 구성: 시간(로컬), 혈당값, 단위, 변화량 Δ(이전 샘플 대비), 변화율 RoC(mg/dL/min), 상태 배지(저/목표/고), 이벤트 아이콘(동시 노출 시 최대 3개 + "+n")
- 단위: `Settings.glucoseUnit` 적용(mg/dL↔mmol 자동 변환; mmol은 소수점 1자리)
- 스냅: 표시 시점은 가장 가까운 실샘플에 스냅. 인접 샘플 간 보간값 표시는 기울임체 + 속이 빈 포인트로 구분
- 접근성: TalkBack/VoiceOver에서 포커스 이동 시 동일 정보 읽기(순서: 시간→값→상태→이벤트)
- 햅틱: 상태 경계(저/고 임계선) 교차 시 약한 진동(설정에서 끄기 가능)

3) 줌/팬 규칙
- TG_01_01(일간·세로)
  - 줌 레벨 프리셋: 3h · 6h · 12h · 24h(기본), 더블탭은 한 단계 확대/축소 순환
  - 핀치로 연속 줌 허용(하한 1h, 상한 24h). 1h 미만 요청은 1h로 클램프
  - 팬: 확대 상태에서만 수평 팬 허용. 범위를 데이터 기간 내로 제한(엘라스틱 바운스 효과)
- TG_01_02(기간·가로)
  - 줌 범위: 6h ~ 72h(3/7/14/30일 스테이트를 프리셋으로 매핑). 프리셋 전환은 상태(state) 변경이며 라우트 유지
  - 팬: 데이터가 존재하는 범위만 허용. 빠른 플링 시 관성 스크롤 적용, 경계 도달 시 감속
- 대시보드 미니 차트: 더블탭→ `TG_01_02`로 전이, 길게 누름은 미사용(SKIP)

4) 임계선/목표 범위 시각화
- `Settings`의 목표 범위(저/목표/고)를 밴드로 표시. 스크럽 시 해당 시점의 상태 배지를 툴팁에 노출
- 임계선 값 변경 시 그래프 즉시 리렌더링(애니메이션 200ms 이내)
- 뷰포트 요약: 현재 가시 범위 내 Time-in-Range(%), 평균, 표준편차를 우측 상단 미니 요약으로 표시

5) 이벤트/마커 상호작용
- 이벤트 유형: 운동·수면·식사·약물·메모(`ME_01_01`) 표시. 동일 시각 다건은 스택 아이콘으로 축약
- 탭: 아이콘 퀵 팝오버(제목/메모 미리보기, [편집] 버튼). [편집]→ `ME_01_01` modal/push
- 빈 영역 롱프레스: "새 이벤트" 컨텍스트 메뉴(유형 선택) → `ME_01_01` 생성 흐름으로 이동, 선택한 타임스탬프 프리필

6) 데이터 스냅/보간/결손 규칙
- 표본 간격: 5분 기준. 스냅 우선순위는 시간차|값변화가 작은 쪽(타입 브레이커: 최신)
- 보간: 샘플 간 간격 ≤10분일 때만 선형 보간. 10분 초과는 점선으로 갭 구간 렌더링 및 "신호 손실" 배지
- 결측 구간에서 스크럽: 툴팁 숨김(상태 안내만 표시), 팬·줌 동작은 유지

7) 성능/품질 기준
- 렌더 목표: 60fps(저사양 30fps 최소). 최초 뷰 진입 TTI ≤ 300ms, 줌/팬 입력-렌더 지연 ≤ 16ms(평균)
- 데이터량: 최대 30일(5분 간격) 처리. 레벨별 디시메이션(시각적 동일성 유지) + 타일 캐싱 적용
- GC 압력 최소화: 객체 재사용, 경로 프리컴파일. 스크럽 중 텍스트 리레이아웃 최소화

8) 접근성/가시성
- High contrast/Colorblind 팔레트 지원(`Settings` 종속). 색상만으로 상태 전달 금지(패턴/아이콘 병행)
- 폰트 스케일 대응: 시스템 글꼴 확대 시 툴팁/축 라벨 자동 리플로우. 탭 타깃 최소 36px 확보

9) 상태/가드
- 센서 웜업(`SC_01_06`): 실시간 스트림은 회색 프록시 라인으로 표시, 스크럽은 가능하나 RoC/상태 배지 비활성화
- 게스트 모드(`LO_01_08`): 이벤트 생성/편집 진입 차단, 팝오버에 로그인 유도 CTA

10) 엣지/정합성
- 시간대/DST 변경: 내부 UTC 저장, 로컬 표시. 뷰포트 경계에서 DST 중복/결손 처리(중복 레이블에 표기)
- 단위 변환: mmol 전환 시 전체 축/툴팁 즉시 변환(소수 1자리, 라운딩 하이라이트 없음)
- 역순 데이터/중복 샘플: 시간 정렬 후 동일 타임스탬프는 최신 레코드 우선, 나머지 폐기

11) QA 체크리스트(요약)
- 제스처 충돌 없음(탭·롱프레스·핀치·팬 병행 시 우선순위: 롱프레스>핀치>팬>탭)
- 경계 교차 햅틱 발생 여부, 임계선 변경 시 리렌더링 시간, 갭 표현 정확성
- 접근성 리더 문구/순서 검증, 색맹 팔레트 대비비 준수(AA)

12) 분석/로그
- 이벤트: chart_view_open, chart_zoom, chart_pan, chart_scrub_start/stop, chart_marker_tap, chart_event_create
- 속성: screen_id(TG_01_01|TG_01_02), range_ms, data_gap, unit, tir_viewport

13) 구현 메모(Flutter)
- 캔버스 기반 레이어 분리: 데이터 레이어(선·밴드), 인터랙션 레이어(크로스헤어/툴팁), 마커 레이어(이벤트)
- 히트테스트: 마커 24px 이내 스냅, 중첩 시 z-순서=최근·중요도 우선(식사>약물>운동>수면>메모)
- 상태 보존: 탭 간 이동 시 각 차트의 줌/팬 상태 유지(메모리 압박 시 LRU로 폐기)

### 14) 트렌드 화면(가로/세로) 추가 스펙

5. 트렌드 화면 (가로모드)
- 5-5. 가로모드 화면은 메인 화면의 그래프 속성을 따릅니다. (4-1~4-4)
- 5-6. 평균값 표시를 크게 수정: 평균값은 현재 X축 가시 범위(window) 내 포인트만으로 실시간 계산·표시
- 5-7. 그래프 밖에 (가로모드 → 세로모드) 복귀 아이콘 추가: 탭 시 세로모드 화면으로 복귀(이전 화면 pop)

6. 트렌드 화면 (세로)
- 6-1. 3h, 6h, 12h, 24h 터치 시 해당 시간만큼 X축 그래프 스케일 자동 변경
  - 최대 축소: 24시간(라벨 간격 3시간), 12시간(라벨 간격 3시간)
  - 최대 확대: 6시간(라벨 간격 1시간), 3시간(라벨 간격 1시간)

