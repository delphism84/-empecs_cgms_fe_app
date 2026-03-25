# 중복 구현에 의한 제거 및 관련 정리

- 기준: req_reanalysis_260313.md, xlsx J/K 고객확인사항
- 작성일: 2026-03-13

---

## 1) 중복 구현에 의한 제거

### Setup → Sensors 패널 제거

| 항목 | 내용 |
|------|------|
| **위치** | `lib/presentation/settings_page/settings_page.dart` |
| **제거 사유** | Sensor 탭(홈 하단)에 이미 센서 Status/Scan&Connect/Serial/Share Data 등이 있음. Setup의 Sensors 패널은 서버 `listSensors` 기반 단순 UI로, 기능 중복 |
| **제거 내용** | ReportCard(title: 'Sensors') 전체, _sensorItem 위젯, sensors 로딩/상태 |
| **유지** | Sensor 탭에서 SC_02_01, SC_03_01, SC_07_01 등 관리 |

---

## 2) 기능 구현 여부 확인 결과

### Setup → Notification, Mute alarm

- **구현됨.** `SettingsPage`에서 토글 시 `_save()` 호출
  - `SettingsStorage`에 `notificationsEnabled`, `alarmsMuteAll` 저장
  - `NotificationService().setEnabled(notificationsEnabled)` 즉시 반영
  - `AlertEngine`이 `alarmsMuteAll`을 참조해 알람 발화 시 무음 처리

### Sensor → Share Data (SC_07_01)

- **구현됨.** Sensor 탭에 "Share Data" 항목 → `SensorSharePage`
  - 기간 선택(1D/7D/30D/Custom), 공유 항목, 이메일/SMS, PDF/CSV 등 설정
  - `SettingsStorage`에 sc0701* 키로 저장

### Setup → 로그아웃 버튼

- **추가 완료.** Account 섹션에 Logout 버튼 추가
  - `authToken`, `lastUserId` 초기화 후 `/login`으로 이동

---

## 3) 미확인 항목 검증 요약 (코드 스캔)

| 페이지ID | 이슈(고객확인) | 코드 검증 결과 |
|----------|----------------|----------------|
| **LO_01_01** | SNS 로그인 안됨, 체크박스 텍스트 깨짐, 생체/간편비번 미노출, 네트워크 에러 | SNS는 mock/엠펙 계정 연동, 실제 OAuth 외부 연동 미확인. 체크박스/생체/간편비번 UI 존재 여부 확인 필요 |
| **LO_01_02** | Google 로그인 연결 구현 X | mock-google 토큰 생성만. 실제 Google OAuth 미확인 |
| **LO_01_04** | 카카오 [올바르지 않는 접근] | mock-kakao 토큰 생성만. 실제 카카오 연동 미확인 |
| **LO_02_01** | 회원가입 시 네트워크 에러 | 네트워크 실패 시 fallback/에러 처리 구현 여부 확인 필요 |
| **SC_01_01** | 체크박스 동의 확인 구현안됨 | `Sc0101PermissionRangeScreen`에 CheckboxListTile 있음. 저장(consent/low/high) 로직 구현됨. "체크박스 부재"는 다른 화면(가입)일 수 있음 |
| **SC_07_01** | 텍스트 깨짐 | 화면별 텍스트 렌더링/다국어 키 확인 필요 |
| **AR_01_01** | 알람 발생 안되어 확인 불가 | 테스트 환경에서 실제 알람 발생 여부. `AlertEngine`은 구현됨 |
