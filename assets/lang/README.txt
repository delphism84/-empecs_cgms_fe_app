lang.xlsx — 다국어 문자열 (앱 번들)
- 첫 시트 이름 권장: `lang` (없으면 첫 번째 시트 사용)
- 1행 헤더: key, en, ko, … (key 고정, 이후 열 이름 = ISO 639-1 언어 코드: en, ko, ja 등)
- `notes` 열은 무시
- 앱 코드: import easy_localization;  'some_key'.tr()  또는 tr('some_key')
- CSV ↔ XLSX 변환: tools/lang-sheet/README.md (npm)
