lang.csv — 다국어 문자열
- 첫 행 헤더: key,en,ko,... (key 고정, 이후 열 이름 = ISO 639-1 언어 코드: en, ko, ja 등)
- 각 행: 고유 key, 영어 문구, 한글 문구, (추가 언어 열)
- 앱 코드: import easy_localization;  'some_key'.tr()  또는 tr('some_key')
- 새 언어 추가: 1) CSV에 열 추가 2) lib/main.dart 의 EasyLocalization supportedLocales 에 Locale('xx') 추가
