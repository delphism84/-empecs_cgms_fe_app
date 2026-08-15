#!/usr/bin/env bash
# 화면 잠금 상태에서 백그라운드 수신이 유지되는지 주기적으로 표본을 뜬다.
#   ADB_DEVICE=<serial> ./tools/qa-lockwatch.sh <샘플수> <간격초> > out.log
# 각 표본: 시각 / 화면상태 / 포그라운드서비스 / dump(누적 trid·건수·드랍) 요약
set -u
DEV="${ADB_DEVICE:-emulator-5554}"
N="${1:-8}"
GAP="${2:-120}"

for i in $(seq 1 "$N"); do
  TS=$(date '+%H:%M:%S')
  WAKE=$(adb -s "$DEV" shell dumpsys power 2>/dev/null | grep -o 'mWakefulness=[A-Za-z]*' | head -1)
  FG=$(adb -s "$DEV" shell dumpsys activity services com.helpcare.app 2>/dev/null | grep -c 'isForeground=true')
  D=$(ADB_DEVICE="$DEV" ./tools/qa-cmd.sh dump 2>/dev/null)
  TRID=$(echo "$D" | grep -o '"lastTrid":[0-9]*' | cut -d: -f2)
  UP=$(echo "$D" | grep -o '"uploadWatermark":[0-9]*' | cut -d: -f2)
  CNT=$(echo "$D" | grep -o '"dbCount":[0-9]*' | cut -d: -f2)
  OFF=$(echo "$D" | grep -o '"lastCgmOffsetMin":[0-9]*' | cut -d: -f2)
  DROP=$(echo "$D" | grep -o '"droppedInserts":[0-9]*' | cut -d: -f2)
  echo "[$TS] $WAKE fgService=$FG lastTrid=$TRID upload=$UP dbCount=$CNT offsetMin=$OFF dropped=$DROP"
  [ "$i" -lt "$N" ] && sleep "$GAP"
done
