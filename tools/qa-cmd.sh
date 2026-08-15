#!/usr/bin/env bash
# QA 원격 명령 헬퍼 (디버그 빌드 전용).
#   ./tools/qa-cmd.sh <cmd> [json-args]
# 예)
#   ./tools/qa-cmd.sh ping
#   ./tools/qa-cmd.sh sensor.setRemaining '{"minutes":719}'
#   ./tools/qa-cmd.sh dump
#
# 결과는 logcat 태그 CGMS_QA 에서 읽어 그대로 출력한다.
set -u
DEV="${ADB_DEVICE:-emulator-5554}"
CMD="${1:?usage: qa-cmd.sh <cmd> [json-args]}"
ARGS="${2:-}"

adb -s "$DEV" logcat -c -b main >/dev/null 2>&1
if [ -n "$ARGS" ]; then
  adb -s "$DEV" shell am broadcast -a com.helpcare.app.QA --es cmd "$CMD" --es args "'$ARGS'" >/dev/null 2>&1
else
  adb -s "$DEV" shell am broadcast -a com.helpcare.app.QA --es cmd "$CMD" >/dev/null 2>&1
fi

for _ in $(seq 1 20); do
  OUT=$(adb -s "$DEV" logcat -d -s CGMS_QA 2>/dev/null | grep -E "(ok|err) $CMD ->" | tail -1)
  if [ -n "$OUT" ]; then
    echo "${OUT#*CGMS_QA : }"
    exit 0
  fi
  sleep 0.5
done
echo "TIMEOUT: no CGMS_QA response for $CMD"
exit 1
