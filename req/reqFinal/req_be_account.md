# 백엔드 계정 API 구현 사양 (req_be_account)

- **대상**: BE 팀 수정용
- **작성일**: 2026-03-13
- **참조**: Flutter 앱 `lib/core/utils/auth_urls.dart`, `lib/presentation/auth/` 회원가입 플로우

---

## 1. API Base

- 앱 `DebugConfig.apiBase` 또는 사용자 설정 `apiBaseUrl` 사용
- 예: `https://api.example.com`

---

## 2. 회원가입 (Register)

### 2.1 엔드포인트

```
POST /api/auth/register
Content-Type: application/json
```

### 2.2 요청 본문 (Request Body)

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `email` | string | O | 이메일 (형식 검증 필요) |
| `password` | string | O | 비밀번호 (8자 이상 권장) |
| `firstName` | string | O | 이름 |
| `lastName` | string | O | 성 |
| `dateOfBirth` | string | O | 생년월일 (ISO 8601 date, 예: `2000-01-15`) |
| `gender` | string | - | `male` \| `female` (앱: `남`/`여` → BE 변환 가능) |
| `unit` | string | - | `mg/dL` \| `mmol` (기본: `mg/dL`) |
| `countryCode` | string | - | 국가 코드 (예: `KR`, `US`) |
| `language` | string | - | 언어 (예: `한국어`, `English`) |
| `agreeTerms` | boolean | O | 이용약관 동의 |
| `agreeResidence` | boolean | - | 국가별 정책 동의 |

**앱 수집 필드(Step2~4) 매핑**

- Step2: `countryCode`, `language`, `agreeResidence`
- Step3: `email`, `password`, `agreeTerms`
- Step4: `firstName`, `lastName`, `email`, `dateOfBirth`, `gender`, `unit`

### 2.3 성공 응답 (201 Created)

```json
{
  "ok": true,
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "usr_xxx",
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe"
  }
}
```

- `token`: 이후 API 호출 시 `Authorization: Bearer <token>` 사용
- `user`: (선택) 프로필 정보

### 2.4 오류 응답

| HTTP | body 예시 | 설명 |
|------|-----------|------|
| 400 | `{"ok": false, "error": "invalid_email"}` | 이메일 형식 오류 |
| 400 | `{"ok": false, "error": "password_too_short"}` | 비밀번호 8자 미만 |
| 409 | `{"ok": false, "error": "email_exists"}` | 이미 가입된 이메일 |
| 422 | `{"ok": false, "error": "validation_failed", "fields": [...]}` | 필수 필드 누락 등 |
| 500 | `{"ok": false, "error": "internal_error"}` | 서버 내부 오류 |

---

## 3. 로그인 (Login) - 참조용

### 3.1 엔드포인트

```
POST /api/auth/login
Content-Type: application/json
```

### 3.2 요청 본문

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `email` | string | O | 이메일 |
| `password` | string | O | 비밀번호 |

### 3.3 성공 응답 (200 OK)

```json
{
  "token": "eyJhbGciOiJIUzI1NiIs..."
}
```

앱은 `token`을 `authToken`으로 저장 후, `lastUserId`에 `email` 저장.

### 3.4 오류 응답

| HTTP | 설명 |
|------|------|
| 401 | 잘못된 이메일/비밀번호 |
| 500 | 서버 오류 |

---

## 4. 클라이언트 연동 요약

- **Register URL**: `{apiBase}/api/auth/register`
- **Login URL**: `{apiBase}/api/auth/login`
- **인증**: `Authorization: Bearer <token>` (로그인/가입 성공 시 받은 token)

---

## 5. 앱 측 향후 작업 (BE 연동 후)

- `CreateAccountStep5ConfirmPage`에서 "Create Account" 버튼 클릭 시:
  1. Step2~4 수집 데이터를 `Map`으로 정리
  2. `ApiClient().post(AuthUrls.register, body: payload)` 호출
  3. 201 시 `token` 저장, `Lo0205SignUpCompleteScreen`으로 이동
  4. 4xx/5xx 시 에러 메시지 표시

- 현재는 백엔드 연동 전이므로 `Lo0205SignUpCompleteScreen`으로 바로 이동.
