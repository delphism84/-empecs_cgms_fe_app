# 2. API ?? ?? ??

## ???

| ?? | GitHub | ??? | ?? |
|------|--------|--------|------|
| CGMS Backend | delphism84/empecs_cgms_be | main | f62657f |
| CGMS Admin FE | delphism84/ln_admin_fe_ref | main | ad19545 |

## ???·??

| ?? | URL / ?? |
|------|------------|
| ??? API (??) | `https://empecs.lunarsystem.co.kr` |
| Web QA (? FE) | `https://empecsuser.lunarsystem.co.kr` |
| BE ?? (Docker) | `be:58002` |
| FE ??? ??? | `127.0.0.1:63104` |

## Docker ??

```bash
cd empecs_cgms_be
docker compose up -d --build cgms-app-fe
```

- Nginx: `/api/*` ? `be:58002` ???
- TLS: certbot + `nginx/empecsuser.lunarsystem.co.kr.conf`

## ?? ?? (??)

| ?? | ?? |
|------|------|
| `MONGO_URI` | MongoDB ?? ??? |
| `BASE_URL` | OAuth ?? ?? URL |
| `JWT_SECRET` | ?? ?? ?? |

## ???? ? API

`report/4_api_spec/api_spec.xlsx` ?? `04_req_cross` ??.
