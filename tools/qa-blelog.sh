#!/usr/bin/env bash
# 기기의 인앱 BLE 로그(`cgms.ble_logs`, SharedPreferences StringList)를 그대로 출력한다.
# 사용: ADB_DEVICE=<serial> ./tools/qa-blelog.sh [줄수]
set -u
DEV="${ADB_DEVICE:-emulator-5554}"
N="${1:-40}"
OUT="${TMPDIR:-/tmp}/qa_prefs_$$.xml"

MSYS_NO_PATHCONV=1 adb -s "$DEV" exec-out run-as com.helpcare.app \
  cat /data/data/com.helpcare.app/shared_prefs/FlutterSharedPreferences.xml > "$OUT" 2>/dev/null

PYTHONIOENCODING=utf-8 python - "$OUT" "$N" <<'PY'
import sys, re, html, json
path, n = sys.argv[1], int(sys.argv[2])
x = open(path, encoding='utf-8', errors='replace').read()
m = re.search(r'name="flutter\.cgms\.ble_logs">(.*?)</string>', x, re.S)
if not m:
    print('(no ble_logs)'); raise SystemExit(0)
raw = html.unescape(m.group(1))
# Flutter SharedPreferences StringList: "<base64 prefix>!<json list>"
body = raw.split('!', 1)[1] if '!' in raw else raw
try:
    items = json.loads(body)
except Exception as e:
    print('parse error:', e); print(body[:300]); raise SystemExit(1)
for line in items[:n]:
    print(line)
PY
rm -f "$OUT"
