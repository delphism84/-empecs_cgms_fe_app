# CGM App QA 검수·캡처 체크리스트 (260313R 기준)

- **대상**: 수정 코드 반영 후 진입점·설정·알람 등 UI/UX 검수 및 스크린샷 캡처
- **실행**: Chrome 웹(`flutter run -d chrome` 또는 `flutter run -d web-server --web-port=8080`) 또는 Android/iOS 실기기
- **캡처 저장**: `req/req260314/qa_captures/` (아래 표의 파일명으로 저장)

---

## 1. 실행 방법

```powershell
cd c:\rc\_cube\empecs\empecs_cgms
flutter run -d chrome
# 또는 고정 포트로 서버만 띄우기:
flutter run -d web-server --web-port=8080
# 브라우저에서 http://localhost:8080 접속
```

---

## 2. 진입점·탭 구조 검수

| # | 화면 | 확인 항목 | 통과 | 비고 | 캡처 파일명 |
|---|------|-----------|:----:|------|-------------|
| 1 | **Home (MAIN_DASHBOARD)** | 진입 시 대시보드 표시, 하단 6탭(Home/Trend/Report/Sensor/Alarm/Settings) 표시 | ☐ | | `01_home.png` |
| 2 | 하단 네비게이션 | 좁은 폭(400px 미만)에서도 6탭 레이블 잘림 없음, 폰트 10px 적용 | ☐ | | `02_nav_narrow.png` |
| 3 | 뒤로가기 | 브라우저 백키 또는 앱 백 시 "Do you want to exit?" 다이얼로그 표시 | ☐ | | `03_exit_dialog.png` |

---

## 3. Settings 화면 검수 (설정 저장·로컬 우선 반영)

| # | 영역 | 확인 항목 | 통과 | 비고 | 캡처 파일명 |
|---|------|-----------|:----:|------|-------------|
| 4 | **General** | Language, Region, Time format, Chart dot size, Notifications, Mute all alarms (AR_01_01) 행 표시 | ☐ | | `04_settings_general.png` |
| 5 | Time format | 24h/12h 선택 시 즉시 반영, 재진입 시 유지 | ☐ | | `05_time_format.png` |
| 6 | Notifications | 토글 On/Off 저장·표시 | ☐ | | `06_notifications.png` |
| 7 | Mute all alarms (AR_01_01) | 토글 저장·표시, Alerts 탭과 동일 키 사용 | ☐ | | `07_mute_all.png` |
| 8 | **Units** | Glucose unit (mg/dL / mmol/L) 표시·저장 | ☐ | | `08_units.png` |
| 9 | **Accessibility** | High contrast, Larger font, Color blind mode 토글 표시·저장 | ☐ | | `09_accessibility.png` |
| 10 | **Alarms 카드** | High/Low/Rate/System 알람 목록, 토글·상세 이동 가능 | ☐ | | `10_settings_alarms.png` |
| 11 | 텍스트 overflow | 긴 subtitle/라벨 말줄임(ellipsis), 레이아웃 넘침 없음 | ☐ | | `11_settings_no_overflow.png` |

---

## 4. Alerts (AR_01_01) 화면 검수

| # | 항목 | 확인 항목 | 통과 | 비고 | 캡처 파일명 |
|---|------|-----------|:----:|------|-------------|
| 12 | **Alerts 루트** | "Alerts (AR_01_01)" 제목, Mute all alarms, Very Low/High/Low/Rate/System 행 | ☐ | | `12_alerts_root.png` |
| 13 | 알람 상세 | 행 터치 시 AlarmDetailPage 진입, threshold·sound·vibrate 편집·저장 | ☐ | | `13_alarm_detail.png` |
| 14 | 반영 완료 속도 | (실기기) 반영 완료 버튼 터치 후 2초 이내 화면 전환 | ☐ | | - |

---

## 5. Sensor (SC_02_01) · 기타 탭

| # | 화면 | 확인 항목 | 통과 | 비고 | 캡처 파일명 |
|---|------|-----------|:----:|------|-------------|
| 15 | **Sensor 탭** | SC_02_01 카드, Status(SC_03_01), Scan & Connect 등 진입 가능 | ☐ | | `15_sensor.png` |
| 16 | **Trend 탭** | 차트·시간축 표시, 단위(glucoseUnit) 반영 | ☐ | | `16_trend.png` |
| 17 | **Report 탭** | RP_01_01 요약·통계 표시 | ☐ | | `17_report.png` |

---

## 6. 레이아웃·반응형

| # | 항목 | 확인 항목 | 통과 | 비고 |
|---|------|-----------|:----:|------|
| 18 | Settings 가로 여백 | width > 600 → 32px, > 400 → 24px, 이하 16px 적용 | ☐ | |
| 19 | ReportCard·알람 행 | 제목·subtitle 1~2줄 ellipsis, Row 넘침 없음 | ☐ | |
| 20 | 단일 스크롤 | Settings·Alerts 세로 스크롤로 전체 노출 | ☐ | |

---

## 7. 캡처 저장 폴더 구조

```
req/req260314/qa_captures/
├── 01_home.png
├── 02_nav_narrow.png
├── …
└── 17_report.png
```

캡처 시 브라우저 개발자도구 또는 OS 캡처 도구 사용. (풀페이지 캡처 권장: Settings·Alerts)

---

## 8. 검수 결과 요약 (작성 예시)

| 구분 | 통과 | 실패 | 비고 |
|------|:----:|:----:|------|
| 진입·탭 |  |  |  |
| Settings |  |  |  |
| Alerts |  |  |  |
| Sensor·Trend·Report |  |  |  |
| 레이아웃 |  |  |  |

**캡처 일시**: _______________  
**실행 환경**: Chrome Web / Android / iOS (해당 표시)
