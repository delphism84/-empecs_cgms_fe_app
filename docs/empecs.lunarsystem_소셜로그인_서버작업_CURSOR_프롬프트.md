# empecs.lunarsystem.co.kr 소셜 로그인 서버 작업 — Cursor 프롬프트 가이드

> SSH로 empecs.lunarsystem.co.kr 서버에 접속한 뒤, Cursor에서 해당 프로젝트를 연 상태로 아래 프롬프트를 순서대로 사용하면 됩니다.

---

## 작업 개요

| 카테고리 | 작업 항목 |
|----------|-----------|
| 정책 페이지 | 개인정보처리방침, 이용약관, 마케팅 동의 페이지 |
| OAuth 콜백 | `/api/oauth/google/callback`, `/api/oauth/apple/callback`, `/api/oauth/kakao/callback` |
| 인증서/HTTPS | SSL 인증서 설정 (Let's Encrypt 등) |
| 웹서버/리버스프록시 | Nginx 등 — API 프록시, 정적 파일 제공 |
| 환경변수 | OAuth 클라이언트 시크릿, JWT 시크릿 등 |
| 웹훅 (선택) | Apple App Store Server Notifications 등 — 소셜 로그인 단순 플로우에는 미사용 |

---

## 1. 개인정보처리방침·이용약관 페이지

Google OAuth 동의화면, Apple, Kakao 등에서 **필수**로 요구하는 URL입니다.  
반드시 `https://empecs.lunarsystem.co.kr` 아래에 제공해야 합니다.

### Cursor 프롬프트

```
empecs.lunarsystem.co.kr에 다음 정책 페이지를 만들어 줘:

1. 개인정보처리방침 (Privacy Policy)
   - URL: https://empecs.lunarsystem.co.kr/privacy.html
   - EMPECS CGMS 앱 관련 수집 항목: 이메일, 프로필(이름·생년월일), 혈당 데이터, 앱 사용 로그
   - 보관·파기 정책, 제3자 제공 금지, 이용자 권리(열람·삭제·동의 철회)
   - 문의처: secure.cg21@empecs.com

2. 이용약관 (Terms of Service)
   - URL: https://empecs.lunarsystem.co.kr/terms.html
   - 서비스 이용 조건, 책임 제한, 약관 변경 공지 방식

3. 마케팅 수집·이용 동의 (선택)
   - URL: https://empecs.lunarsystem.co.kr/marketing.html
   - 선택 동의 항목에 대한 안내

각 페이지는 모바일·PC 모두 읽기 편한 단일 HTML로, 한국어 기준으로 작성해 줘.
웹 루트(예: /var/www/empecs 또는 nginx 정적 경로)에 배치할 수 있게 해 줘.
```

---

## 2. OAuth 콜백 서버 라우트 구현

`social_login_고객안내.html`에 정의된 콜백 경로:

- Google: `https://empecs.lunarsystem.co.kr/api/oauth/google/callback`
- Apple:  `https://empecs.lunarsystem.co.kr/api/oauth/apple/callback`
- Kakao:  `https://empecs.lunarsystem.co.kr/api/oauth/kakao/callback`

### Cursor 프롬프트

```
empecs 백엔드(backend/)에 OAuth 콜백 라우트를 추가해 줘.

필요한 경로:
- GET /api/oauth/google/callback  (authorization code 수신 후 토큰 교환)
- GET /api/oauth/apple/callback   (id_token, user 정보 수신)
- GET /api/oauth/kakao/callback   (authorization code 수신 후 토큰 교환)

요구사항:
1. 환경변수로 관리할 값: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, KAKAO_REST_API_KEY, APPLE_SERVICES_ID, APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY_PATH (또는 APPLE_PRIVATE_KEY)
2. 성공 시: JWT 발급 후 리다이렉트 (예: helpcare://auth?token=xxx 또는 웹 앱 도메인으로)
3. 실패 시: 적절한 에러 페이지 또는 리다이렉트
4. 기존 User 모델과 연동: 이메일·provider(google|apple|kakao)·providerSub로 기존 사용자 매칭 또는 신규 생성
5. config.js에 OAuth 관련 설정 추가
6. CORS가 empecs.lunarsystem.co.kr 도메인을 허용하는지 확인
```

---

## 3. SSL 인증서 설정

### Cursor 프롬프트

```
empecs.lunarsystem.co.kr 도메인에 HTTPS를 적용하려고 해.

1. Let's Encrypt (certbot) 사용 여부 확인
2. nginx 또는 apache 설정에서 empecs.lunarsystem.co.kr용 server 블록에 SSL 인증서 경로 설정
3. HTTP → HTTPS 301 리다이렉트 적용
4. HSTS 헤더 권장 설정

현재 nginx/apache 설정 파일 위치와 내용을 확인한 뒤, SSL 적용 예시를 알려 줘.
```

---

## 4. 웹서버(리버스프록시) 설정

### Cursor 프롬프트

```
empecs.lunarsystem.co.kr 서버 구성을 정리해 줘.

1. Nginx(또는 Apache) 설정에서:
   - / → Flutter 웹 빌드 또는 정적 파일
   - /api/* → Node.js 백엔드(예: 포트 58002)로 프록시
   - /privacy.html, /terms.html, /marketing.html → 정적 HTML 제공

2. 백엔드가 pm2 등으로 기동 중이면, 재시작·로그 확인 방법

3. proxy_set_header Host, X-Forwarded-For, X-Forwarded-Proto 등이 설정되어 있는지 확인
```

---

## 5. 환경변수 및 보안 설정

### Cursor 프롬프트

```
empecs 백엔드 OAuth·보안용 환경변수 템플릿을 만들어 줘.

필수 항목:
- JWT_SECRET (프로덕션용 강한 시크릿)
- MONGO_URI (또는 기존 DB 설정)
- GOOGLE_CLIENT_ID
- GOOGLE_CLIENT_SECRET
- KAKAO_REST_API_KEY (또는 REST API 키)
- APPLE_SERVICES_ID (com.empecs.cg21.web)
- APPLE_TEAM_ID
- APPLE_KEY_ID
- APPLE_PRIVATE_KEY (또는 .p8 파일 경로)
- APPLE_CLIENT_ID (Services ID)
- (선택) OAuth 성공/실패 리다이렉트 URL

.env.example 형태로 작성하고, .env는 .gitignore에 있는지 확인해 줘.
민감한 값은 코드에 하드코딩하지 않도록 해 줘.
```

---

## 6. 배포 후 검증

### Cursor 프롬프트

```
empecs.lunarsystem.co.kr 소셜 로그인 관련 엔드포인트를 검증해 줘.

확인할 URL:
- https://empecs.lunarsystem.co.kr (메인)
- https://empecs.lunarsystem.co.kr/privacy.html
- https://empecs.lunarsystem.co.kr/terms.html
- https://empecs.lunarsystem.co.kr/api/health
- https://empecs.lunarsystem.co.kr/api/oauth/google/callback (실제 로그인 테스트 전 404가 아니면 OK)

curl 또는 스크립트로 각 URL의 HTTP 상태 코드를 확인하는 방법을 알려 줘.
```

---

## 7. 웹훅 설정 (필요 시)

Apple Sign In, Google Play Billing 등에서 서버 알림용 웹훅을 사용하는 경우만 해당합니다.  
**일반 소셜 로그인(OAuth code flow)에는 웹훅이 필요 없습니다.**

### Cursor 프롬프트 (웹훅 사용 시)

```
empecs.lunarsystem.co.kr에 웹훅 엔드포인트를 추가해 줘.

예: POST /api/webhooks/apple  (Apple App Store Server Notifications)
- 요청 서명 검증
- 로그 저장 (수신 페이로드)
- 비동기 처리 큐 연동 (선택)

nginx에서 /api/webhooks/* 경로가 백엔드로 프록시되는지 확인해 줘.
```

---

## 참고: OAuth 콘솔에 등록할 URL 정리

| 용도 | URL |
|------|-----|
| 홈페이지·앱 주소 | https://empecs.lunarsystem.co.kr |
| 개인정보처리방침 | https://empecs.lunarsystem.co.kr/privacy.html |
| 이용약관 | https://empecs.lunarsystem.co.kr/terms.html |
| Google 리디렉션 URI | https://empecs.lunarsystem.co.kr/api/oauth/google/callback |
| Apple Return URL | https://empecs.lunarsystem.co.kr/api/oauth/apple/callback |
| Kakao Redirect URI | https://empecs.lunarsystem.co.kr/api/oauth/kakao/callback |

---

## 외부(고객) 콘솔에서 할 작업

아래는 **empecs.lunarsystem.co.kr 서버 작업이 아님**. Google/Apple/Kakao 각 콘솔에서 직접 설정하는 작업입니다.

- **Google Cloud Console**: OAuth 동의화면(개인정보처리방침 URL 입력), 웹 클라이언트 리디렉션 URI 등록
- **Apple Developer**: Domains and Subdomains, Return URLs 등록
- **Kakao Developers**: Redirect URI, 플랫폼(Web/Android/iOS) 설정

자세한 값은 `docs/social_login_고객안내.html` 참고.
