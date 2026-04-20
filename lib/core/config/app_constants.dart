/// 앱 전역 상수 — 기간·유효일 등 한곳에서 조정
class AppConstants {
  AppConstants._();

  /// 센서 사용 기준일(표시·진행률·시드 등 공통)
  static const int defaultSensorValidityDays = 15;

  static Duration get sensorValidityDuration =>
      const Duration(days: defaultSensorValidityDays);
}
