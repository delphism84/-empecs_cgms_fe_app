/// 앱 전역 상수 — 기간·유효일 등 한곳에서 조정
class AppConstants {
  AppConstants._();

  /// 센서 사용 기준일(표시·진행률·시드 등 공통)
  /// 요구/실사용 기준은 16일. 15일로 두면 16일 센서가 하루 일찍 `0 Days left` 로 표시된다.
  static const int defaultSensorValidityDays = 16;

  static Duration get sensorValidityDuration =>
      const Duration(days: defaultSensorValidityDays);

  /// 만료 예고 알림 시작 시점(만료까지 남은 시간).
  static const Duration sensorExpiryWarnBefore = Duration(hours: 12);
}
