## qa-bot (CGMS req1 QA 리포트)

검수 완료된 요구사항을 **JSON으로 누적 기록**하고, **HTML 리포트**를 생성합니다.  
가능하면 **ADB 스크린샷(PNG) → JPG 변환**까지 자동으로 수행해 HTML에 포함합니다.

### 설치

```bash
cd tools/qa-bot
npm install
```

### 리포트 위치

- `req/req1/_qa/qa-results.json`
- `req/req1/_qa/index.html`
- (스크린샷) `req/req1/_qa/screenshots/*.jpg`

### 현재까지(예: AR_01_02) seed

앱이 떠 있고, PC에서 `127.0.0.1:18789`로 `BleEmuServer`에 접근 가능할 때(ADB forward 된 상태) 실행:

```bash
node tools/qa-bot/src/cli.js seed:current --id AR_01_02 --port 18789 --screenshot
```

### 검수 완료 기록 추가(앞으로 계속 이걸로 누적)

```bash
node tools/qa-bot/src/cli.js record --id AR_01_03 --title "고혈당 알람 설정/적용" --result pass ^
  --verify "node tools/ble-emu/src/cli.js bot:alarms --backend http://<BE>:58002 --port 18789 --eqsn LOCAL" ^
  --verify "node tools/ble-emu/src/cli.js app:stats --port 18789 (lastAlert 확인)" ^
  --port 18789 --screenshot
```

### HTML 재생성만

```bash
node tools/qa-bot/src/cli.js report
```

### Android 자체 검수 QA (QR 스캔 성공 시뮬 → BLE 스캔 화면)

1. 기기 USB 연결 후 `adb devices` 확인
2. 앱을 **디버그 모드**로 실행: `flutter run` (에뮬 서버가 기기 내 8788 포트에서 동작)
3. 포트 포워딩: `adb forward tcp:18789 tcp:8788`
4. 실행:

```bash
node tools/qa-bot/src/android-qa-qr-ble.js --port 18789
```

- 에뮬 접근 가능 시: QR 성공 시뮬 → BLE 스캔 화면으로 이동 → 스크린샷 저장
- 에뮬 미접속 시: 현재 화면만 스크린샷 (앱을 디버그로 실행 후 다시 시도)
- 결과: `req/req260314/qa_captures/android_qa_qr_ble_<ts>.jpg`, `android_qa_qr_ble_result.json`

