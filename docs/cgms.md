CGMS BLE 통신 흐름 정리 (앱 구현 기준)

개요
- 서비스: Continuous Glucose Monitoring Service (UUID: 0x181F)
- 특성(주요):
  - CGM Measurement (UUID: 0x2AA7) – 실시간 측정값 Notify
  - CGM Specific Ops Control Point (UUID: 0x2AAC) – 세션 제어, 시간 동기 등 제어 명령
- (참고) CGM Feature(0x2AA8), Session Start Time(0x2AAB), Current Time(0x2A2B) 등은 표준에 존재하나 현재 앱에서는 필수 범위만 사용

본 구현은 표준에 맞춘 기본 흐름(세션 시작, 실시간 Notify 구독)을 따르며, 벤더 확장 필드로 Transaction ID(trid)를 함께 다룹니다.

UUID 매핑 (앱 구현)
- Service(CGM): 0000181F-0000-1000-8000-00805F9B34FB
- Characteristic
  - CGM Measurement: 00002AA7-0000-1000-8000-00805F9B34FB
  - CGM Specific Ops Control Point: 00002AAC-0000-1000-8000-00805F9B34FB

연결 및 초기화 시퀀스
1) 스캔/연결
   - 권한 확인 후 CGMS 서비스 UUID로 스캔
   - 대상 디바이스에 연결
   - 디버그 토스트: "BLE: connecting…", "BLE: connected"

2) 세션 시작 (Ops Control)
   - Specific Ops Control Point(0x2AAC)에 Start Session(Opcode 0x01) 전송
   - 결과 토스트: "CGMS: ops start ok/fail"
   - 시간 동기화: 제조사 스펙에 따라 0x2AAC/Current Time(0x1805/0x2A2B) 조합 사용. 현재 앱은 기본 세션 개시까지만 구현(추가 연동 예정)

3) 실시간 Notify 구독
   - CGM Measurement(0x2AA7) Notify Subscribe
   - 토스트: "CGMS: subscribe notify"

실시간 데이터 수신/파싱
- 수신 바이트: CGM Measurement(0x2AA7, IEEE-11073 SFLOAT 기반)
- 현재 파싱 항목
  - Glucose Concentration(SFLOAT) → mg/dL (범위/유효성 검사 포함)
  - Transaction ID(trid): 벤더 확장(데모), 3~4바이트(LE)
- 수신 시 후속 처리
  - lastTrid를 로컬 저장(SettingsStorage)
  - 인제스트 큐로 전달 → 서버 저장(POST /api/data/glucose, body: time, value, trid)
  - UI 브로드캐스트(DataSyncBus)로 차트/카드 즉시 갱신
  - 디버그 토스트: "CGMS: notify v=### trid=####"

시뮬레이션(랜덤 데이터) 경로
- BleService.simulateNotify(value)
  - lastTrid를 1씩 증가(16-bit 롤오버)시켜 가상 payload 생성
  - 동일한 Notify 파이프라인으로 주입하여 실제 디바이스 수신과 동일하게 동작(서버 저장/차트 갱신)

데이터 영속화 및 캐싱 동기화
- 앱 → 인제스트 큐 → 서버 POST /api/data/glucose
- 백엔드 모델: GlucosePoint { userId, time, value, trid }
- 차트/목록 동기화
  - 하단 이벤트/포인트 목록: 서버 재조회 후 즉시 반영
  - 차트 뷰포트: 우측 앵커 상태일 때 최신 데이터의 우측 끝에 자동 정렬 유지

알림/토스트
- NotificationService(on/off)
  - off: 시스템 알림 표시 안 함
  - on: 저/고혈당 경보 등 표시
- DebugToastBus: BLE 연결/OPS/구독/Notify 각 단계 스낵바 노출

표준 대비 구현 상태
- 구현됨
  - CGMS 서비스/특성 UUID로 연결/구독
  - OPS Start(0x01) 전송 및 세션 개시
  - Measurement(SFLOAT) 파싱, 서버 저장, 실시간 UI 반영
  - 벤더 확장 trid 관리/저장
- 보완 예정(표준 정합 고도화)
  - Time Synchronization: Current Time Service(0x1805/0x2A2B) 또는 0x2AAC 시간 관련 opcode 적용
  - CGM Feature(0x2AA8) 읽기 및 기능 협상
  - Measurement 플래그/Status Annunciation 등 추가 필드 파싱
  - RACP/히스토리 동기화(필요 시)

참조(코드 위치)
- BLE 서비스
  - lib/core/utils/ble_service.dart (연결/OPS/구독/파싱/시뮬레이터)
- 인제스트 큐/서버 저장
  - lib/core/utils/ingest_queue.dart
  - lib/core/utils/api_client.dart (postGlucose)
- 백엔드
  - backend/src/models/GlucosePoint.js
  - backend/src/routes/data.js (glucose 라우트)
- 디버그 토스트
  - lib/core/utils/debug_toast.dart


