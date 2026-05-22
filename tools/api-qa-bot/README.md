# API QA Bot

Flutter 앱(`lib/**/*.dart`)이 호출하는 BE 엔드포인트를 **한 번에** 검증합니다.  
Node 18+ (`fetch`). `tools/api-qa-bot/run.mjs`가 단일 진입점이며, `tools/online-sync-mock`는 동기화 최소 시나리오만 빠르게 돌릴 때 쓸 수 있습니다.

## 필수 검증 (실패 시 exit 1)

| 단계 | 메서드 | 경로 |
|------|--------|------|
| 온라인 프로브 | GET | `/api/settings/app` (비인증 → 401/403) |
| 가입 또는 로그인 | POST | `/api/auth/register` 또는 `/api/auth/login` |
| 프로필 | GET | `/api/auth/me` |
| 앱 설정 | GET | `/api/settings/app` (인증) |
| 혈당 목록 | GET | `/api/data/glucose` |
| 이벤트 목록 | GET | `/api/data/events` |
| EQ resolve | GET | `/api/settings/eq-list/resolve` (200/404) |
| EQ upsert | POST | `/api/settings/eq-list` |
| EQ 단건 | GET | `/api/settings/eq-list/:serial` (200/404) |
| 혈당 배치 | POST | `/api/data/glucose/batch` |
| 혈당 단건 | POST | `/api/data/glucose` |
| 이벤트 배치 | POST | `/api/data/events/batch` (없으면 단건 ×2) |
| 이벤트 삭제 | DELETE | `/api/data/events/:id` 멱등 ×2 |

## 옵션 (기본: 실패해도 전체 통과, `--strict`면 실패 시 exit 1)

- `PUT /api/settings/app`
- `POST /api/settings/alarms` (+ 생성 시 `DELETE` 정리)
- `RUN_DESTRUCTIVE=1` 일 때만: `DELETE /api/data/glucose/clear`, `DELETE /api/data/events/clear`

## 실행

```bash
cd tools/api-qa-bot
npm run qa
```

```bash
set API_BASE=https://your-api.example.com
npm run qa
```

```bash
set SKIP_REGISTER=1
set LOGIN_EMAIL=user@lunarsystem.co.kr
set LOGIN_PASSWORD=secret
npm run qa
```

JSON 리포트:

```bash
node run.mjs --json-out=../../req/_qa/api-qa-report.json
```

## Flutter에서 동일 검증

전체 BE 시나리오는 `test/be_api_full_qa_test.dart` 에서  
`--dart-define=RUN_BE_FULL_QA=true` 로 켤 수 있습니다 (네트워크·테스트 계정 필요).

```bash
flutter test test/be_api_full_qa_test.dart --dart-define=RUN_BE_FULL_QA=true
```

일상 CI는 `flutter test`(스모크만) + 필요 시 본 봇(`npm run qa`)을 권장합니다.
