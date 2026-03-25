class Passcode {
  static final RegExp _re = RegExp(r'^\d{4}$');

  static bool isValid(String code) => _re.hasMatch(code.trim());

  /// 가벼운 해시(보안 목적이 아니라 "평문 저장 회피" 수준)
  /// - 외부 의존성(crypto) 없이 사용하기 위해 FNV-1a 32bit 사용
  static String hash(String code) {
    final String s = 'cgms:$code';
    int h = 0x811C9DC5; // offset basis
    for (int i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}

