# profiles-api

NestJS HTTP service exposing profile information.

## Endpoints

| Method | Path       | Response                                      |
| ------ | ---------- | --------------------------------------------- |
| GET    | `/`        | `{ "service": "profiles-api", "sha": "..." }` |
| GET    | `/healthz` | `{ "status": "ok" }`                          |

## Environment Variables

| Variable   | Default       | Description                  |
| ---------- | ------------- | ---------------------------- |
| `PORT`     | `8080`        | HTTP listen port             |
| `GIT_SHA`  | `unknown`     | Git commit SHA for `/` response |
| `NODE_ENV` | `development` | Node environment             |

## Development

```bash
# From repo root
pnpm --filter profiles-api dev

# Or from this directory
pnpm dev
```

## Build & Run

```bash
pnpm build
NODE_ENV=production GIT_SHA=$(git rev-parse HEAD) pnpm start
```

## Docker

Build from the **repo root**:

```bash
docker build -f services/profiles-api/Dockerfile -t profiles-api .
docker run -p 8080:8080 -e GIT_SHA=$(git rev-parse HEAD) profiles-api
```
