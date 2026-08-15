#!/usr/bin/env bash
# 실기기 스크린샷 저장. 폴더블처럼 디스플레이가 여러 개인 기기는 -d 로 지정해야
# `screencap` 이 경고 텍스트를 뱉고 PNG 가 아닌 파일을 만든다.
#   ADB_DEVICE=<serial> QA_DISPLAY_ID=<id> ./tools/qa-shot.sh <출력경로.png>
set -eu
DEV="${ADB_DEVICE:-emulator-5554}"
OUT="${1:?usage: qa-shot.sh <out.png>}"
mkdir -p "$(dirname "$OUT")"

if [ -n "${QA_DISPLAY_ID:-}" ]; then
  adb -s "$DEV" exec-out screencap -d "$QA_DISPLAY_ID" -p > "$OUT"
else
  adb -s "$DEV" exec-out screencap -p > "$OUT"
fi

# PNG 시그니처 확인 — 아니면 경고 텍스트가 저장된 것이다.
if ! head -c 8 "$OUT" | od -An -tx1 | grep -q "89 50 4e 47"; then
  echo "ERROR: $OUT is not a PNG (multi-display? set QA_DISPLAY_ID)" >&2
  head -c 200 "$OUT" >&2; echo >&2
  exit 1
fi
echo "$OUT ($(wc -c < "$OUT") bytes)"
