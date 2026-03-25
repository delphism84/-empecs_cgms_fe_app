/// QR 라벨 파싱 공통 유틸
///
/// QR 형식: #1;#2;#3 (세미콜론 구분)
/// #1 ADV 이름   : empecsCGM (기본값)
/// #2 ID+MAC    : 제조자ID(0xFFFF) + MAC 6byte, 예: 0xFFFF04AC44111111
/// #3 일련번호  : 0xC21ZS00101 (센서데이터/기타정보용)
class QrSnParser {
  QrSnParser._();

  static final RegExp _legacySn = RegExp(r'(C\d{2})([A-Z])(S?)(\d{5})');

  /// 새 형식(#1;#2;#3) 파싱. 성공 시 { advName, idMac, mac, serial, model?, year?, sampleFlag? } 반환
  static Map<String, String>? parse(String v) {
    final String raw = v.trim();
    if (raw.isEmpty) return null;

    final List<String> parts = raw.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 3) {
      final String advName = parts[0];
      final String idMacRaw = parts[1].replaceFirst(RegExp(r'^0x'), '').replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
      final String serialRaw = parts[2].replaceFirst(RegExp(r'^0x'), '').toUpperCase();

      String mac = '';
      if (idMacRaw.length >= 12) {
        final String macHex = idMacRaw.length > 12 ? idMacRaw.substring(idMacRaw.length - 12) : idMacRaw;
        mac = '${macHex[0]}${macHex[1]}:${macHex[2]}${macHex[3]}:${macHex[4]}${macHex[5]}:'
            '${macHex[6]}${macHex[7]}:${macHex[8]}${macHex[9]}:${macHex[10]}${macHex[11]}';
      }

      final Map<String, String> result = {
        'advName': advName,
        'idMac': parts[1],
        'mac': mac,
        'serial': serialRaw,
      };
      final RegExpMatch? snMatch = _legacySn.firstMatch(serialRaw);
      if (snMatch != null) {
        result['model'] = snMatch.group(1)!;
        result['year'] = snMatch.group(2)! == 'Z' ? '2025' : '';
        result['sampleFlag'] = snMatch.group(3) ?? '';
      } else {
        result['model'] = '';
        result['year'] = '';
        result['sampleFlag'] = '';
      }
      return result;
    }

    if (parts.length == 1) {
      final String t = parts[0].toUpperCase();
      final RegExpMatch? m = _legacySn.firstMatch(t);
      if (m != null) {
        return {
          'advName': 'empecsCGM',
          'idMac': '',
          'mac': '',
          'serial': m.group(4)!,
          'model': m.group(1)!,
          'year': m.group(2)! == 'Z' ? '2025' : '',
          'sampleFlag': m.group(3) ?? '',
        };
      }
    }
    return null;
  }

  /// fullSn 추출 (#3 일련번호). 새 형식이면 #3, 구형식이면 C21ZS00033 스타일
  static String? fullSn(String v) {
    final String raw = v.trim();
    if (raw.isEmpty) return null;
    final List<String> parts = raw.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 3) {
      return parts[2].replaceFirst(RegExp(r'^0x'), '').toUpperCase();
    }
    final String t = raw.toUpperCase();
    final RegExpMatch? m = _legacySn.firstMatch(t);
    return m == null ? null : t.substring(m.start, m.end);
  }
}
