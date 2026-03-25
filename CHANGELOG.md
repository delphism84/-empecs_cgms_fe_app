# Changelog

## 2025-03-17

- 센서 연결 시 Start Time이 자동으로 BT 연결 시점으로 저장됩니다.
- 로그아웃 시 센서 연결이 해제되고 QR, 일련번호, BLE 주소가 삭제됩니다.
- Glucose Report Share 버튼 터치 시 Data Share 화면으로 이동합니다.
- 메인 차트의 고혈당/저혈당 라인이 알람 설정값에 맞게 표시됩니다.
- Scan & Connect에서 BLE 스캔을 먼저 하고 QR 스캔 버튼은 하단에 배치했습니다.
- BT Connect Guide에서 Sensor Connect 버튼을 맨 아래에 두어 가이드 스크롤 후 눌 수 있습니다.
- 웜업 화면 Continue 버튼을 제거하고, 시간 숫자를 길게 누르면 건너뛰기(개발자용)가 됩니다.
- QR 스캔 후 Save & Sync 시 Start the Monitor 화면에서 BLE 자동 검색이 진행됩니다.
- Start the Monitor에 진행 상황(현재/전체) 표시와 Cancel 버튼을 추가했습니다.
- 연결 실패 시 안내 모달이 표시됩니다.
- Serial Number 화면의 Save & Sync 시 BLE 검색 화면으로 바로 이동합니다.
- QR 코드 형식을 ADV;ID+MAC;일련번호(#1;#2;#3)로 지원합니다.
- QR 스캔 결과 화면에 QR 이미지와 스캔 데이터가 표시됩니다.
- 로그인 시 네트워크 오류가 나면 로컬 로그인으로 앱을 사용할 수 있습니다.
- 관련 화면 문구를 영어로 통일했습니다(QR Scan, BLE Scan, Save & Sync 등).
