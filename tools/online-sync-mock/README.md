# online-sync-mock

Flutter `OnlineMonitor`와 동일한 순서로 BE를 두드려 보는 **Node 18+** 스크립트입니다.

**전체 앱·BE 계약 검증**은 [`../api-qa-bot/`](../api-qa-bot/README.md) 의 `npm run qa` 를 사용하세요.

1. `POST /api/auth/register` (기본) 또는 `SKIP_REGISTER=1` + 로그인  
2. `GET /api/settings/app`  
3. `POST /api/data/glucose/batch` (더미 `eqsn` / `t` / `v` / `tr`)  
4. `POST /api/data/events/batch` — **404**면 단건 `POST /api/data/events` ×2로 폴백 (구 서버 호환)

## 검증 내용

- `GET /api/settings/app` — 토큰 없음 → **401/403**
- `POST /api/auth/register` (또는 로그인)
- `GET /api/settings/app` — 토큰 있음 → **200**
- `POST /api/data/glucose/batch` — **2xx**
- `POST /api/data/events/batch` — **2xx** 이거나 **404** 시 단건 `POST /api/data/events` ×2 (각 **2xx**)
- 배치 미사용 시 생성된 이벤트로 `DELETE` 멱등 **200** ×2

실패 시 프로세스 **exit 1**.

## 실행

```bash
cd tools/online-sync-mock
npm run sync
```

다른 호스트:

```bash
set API_BASE=https://your-staging.example.com
npm run sync
```

기존 계정만 쓰려면:

```bash
set SKIP_REGISTER=1
set LOGIN_EMAIL=you@lunarsystem.co.kr
set LOGIN_PASSWORD=YourPass
npm run sync
```

## Flutter 연동

앱은 `DataService.postEventsBatch`로 이벤트를 **최대 200건** 묶어 올리고, 실패 시 기존처럼 **건당 `postEvent`**로 재시도합니다 (`lib/core/utils/online_monitor.dart`).
