import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;

/// `pdf` 기본 글꼴은 한글 글리프가 없어 PDF에서 □/깨짐이 난다.
/// 우선 번들 `assets/fonts/NotoSansKR-*.ttf`가 있으면 사용하고,
/// 없으면 **fonts.gstatic.com** 정적 TTF(Noto Sans KR, package:printing과 동일 출처)를 내려받아 임베드한다.
class PdfCjkFonts {
  PdfCjkFonts._();

  /// package:printing `PdfGoogleFonts.notoSansKRRegular()` 와 동일 URL
  static const String _gstaticRegular =
      'https://fonts.gstatic.com/s/notosanskr/v36/PbyxFmXiEBPT4ITbgNA5Cgms3VYcOA-vvnIzzuoyeLTq8H4hfeE.ttf';

  /// package:printing `PdfGoogleFonts.notoSansKRBold()` 와 동일 URL
  static const String _gstaticBold =
      'https://fonts.gstatic.com/s/notosanskr/v36/PbyxFmXiEBPT4ITbgNA5Cgms3VYcOA-vvnIzzg01eLTq8H4hfeE.ttf';

  static pw.Font? _base;
  static pw.Font? _bold;
  static Future<void>? _loadFuture;

  static Future<void> ensureInitialized() {
    _loadFuture ??= _load();
    return _loadFuture!;
  }

  static Future<void> _load() async {
    if (_base != null && _bold != null) return;
    try {
      final ByteData reg = await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf');
      final ByteData bd = await rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf');
      _base = pw.Font.ttf(reg);
      _bold = pw.Font.ttf(bd);
      return;
    } catch (e, st) {
      assert(() {
        debugPrint('PdfCjkFonts: bundle NotoSansKR missing ($e), fetching from gstatic…\n$st');
        return true;
      }());
    }

    final http.Client client = http.Client();
    try {
      final regResp = await client.get(Uri.parse(_gstaticRegular));
      final bdResp = await client.get(Uri.parse(_gstaticBold));
      if (regResp.statusCode != 200 || bdResp.statusCode != 200) {
        throw StateError(
          'NotoSansKR download failed: HTTP ${regResp.statusCode} / ${bdResp.statusCode}',
        );
      }
      _base = pw.Font.ttf(ByteData.sublistView(regResp.bodyBytes));
      _bold = pw.Font.ttf(ByteData.sublistView(bdResp.bodyBytes));
    } finally {
      client.close();
    }
  }

  static pw.ThemeData get theme {
    final pw.Font? b = _base;
    final pw.Font? bb = _bold;
    if (b == null || bb == null) {
      throw StateError('PdfCjkFonts.ensureInitialized() must complete before theme is used');
    }
    return pw.ThemeData.withFont(base: b, bold: bb);
  }
}
