# EMPECS CGMS 앱 — Web QA (`empecsuser.lunarsystem.co.kr`)

## 목적

- **동일 백엔드·DB** (`empecs_cgms_be` Docker 스택)에 붙여, **로그인·차트·설정·데이터 API** 등을 브라우저에서 빠르게 검증합니다.
- **실제 안드로이드 기기**에서만 필요한 것은 **BLE(블루투스)** 쪽입니다. 나머지 UX·API·동기화는 Web QA로 대부분 커버됩니다.
- OAuth 콜백 URL은 백엔드 `BASE_URL`(기본 `https://empecs.lunarsystem.co.kr`) 기준이라, 소셜 로그인은 필요 시 **empecs** 도메인에서 한 번 더 확인하는 흐름이 될 수 있습니다. (이메일/비번 로그인은 Web에서 그대로 테스트 가능)

## API 베이스 URL

| 플랫폼 | 동작 |
|--------|------|
| **Flutter Web** (이 배포) | `DebugConfig.apiBase` → **현재 페이지 오리진** (`https://empecsuser...`). Nginx(앱 컨테이너)가 `/api/*` 를 `be:58002` 로 넘김. |
| **Android / iOS** | 기본 `https://empecs.lunarsystem.co.kr` (설정의 `apiBaseUrl`으로 덮어쓰기 가능). |

## Docker (레포 루트 `empecs_cgms_be`)

```bash
cd /path/to/empecs_cgms_be
docker compose up -d --build cgms-app-fe
```

호스트에서 앱 컨테이너: **`127.0.0.1:63104`**.

## 호스트 Nginx + TLS

1. DNS: `empecsuser.lunarsystem.co.kr` → 서버 IP.
2. 인증서:  
   `sudo certbot certonly --webroot -w /var/www/html -d empecsuser.lunarsystem.co.kr`
3. 설정 복사:  
   `empecs_cgms_be/nginx/empecsuser.lunarsystem.co.kr.conf` → `/etc/nginx/sites-available/empecsuser` 후 `sites-enabled` 링크, `nginx -t` / reload.

인증서 없이 내부만 볼 때는 `63104` 로 직접 접속해 확인할 수 있습니다.

## Flutter 로컬 개발 (Chrome)

```bash
cd cgms_app_fe
flutter pub get
flutter run -d chrome
```

Web에서는 기본적으로 오리진이 `localhost` 이므로, **로컬 BE** (`127.0.0.1:63101` 등)로 붙이려면 앱 설정의 `apiBaseUrl` 또는 환경에 맞게 조정하면 됩니다.
