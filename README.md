# playg-profiles

Monorepo for profile-related backend services, built with **pnpm workspaces**, **NestJS**, **TypeScript**, and **Node.js 20**.

## Monorepo Layout

```
package.json              ← workspace root (scripts, shared devDeps, semantic-release)
pnpm-workspace.yaml       ← declares services/*
.releaserc.json           ← semantic-release config (runs on master)
services/
  profiles-api/
    src/
      main.ts             ← NestJS bootstrap (port 8080)
      app.module.ts       ← root module
      app.controller.ts   ← GET / and GET /healthz
    Dockerfile            ← multi-stage production image
    scripts/
      tag-ecr.sh          ← re-tag ECR images without rebuilding
      wait-argocd-app.sh  ← poll Argo CD until Synced+Healthy
.github/workflows/
  ci.yml                  ← PR / push lint+build+test
  release-and-promote.yml ← build image → int tag → gate → release → stg tag → gate
```

## Prerequisites

- **Node.js 20**
- **pnpm 9.x** (`corepack enable && corepack prepare pnpm@9.15.4 --activate`)
- **Docker** (for image builds)

## Local Development

```bash
# Install all dependencies
pnpm install

# Run profiles-api in dev mode (hot-reload via tsx)
pnpm dev

# Or run just one service
pnpm --filter profiles-api dev
```

The server starts on `http://localhost:8080`:

| Endpoint   | Response                                     |
| ---------- | -------------------------------------------- |
| `GET /`    | `{ "service": "profiles-api", "sha": "..." }`|
| `GET /healthz` | `{ "status": "ok" }`                    |

## Build

```bash
pnpm build          # compiles all services to dist/
pnpm start          # (from service dir) runs compiled JS
```

## Docker

Build from the **repo root** (the Dockerfile expects workspace context):

```bash
docker build -f services/profiles-api/Dockerfile -t profiles-api .
docker run -p 8080:8080 -e GIT_SHA=$(git rev-parse HEAD) profiles-api
```

The image uses `node:24-slim`, runs as a non-root user, and sets `NODE_ENV=production`. Runtime dependencies (NestJS, reflect-metadata, rxjs) are included via `pnpm deploy --prod`.

## Conventional Commits

This repo uses [Conventional Commits](https://www.conventionalcommits.org/) to drive **semantic-release**. Prefix your commit messages:

| Prefix     | Bump  | Example                             |
| ---------- | ----- | ----------------------------------- |
| `fix:`     | patch | `fix: handle null profile gracefully` |
| `feat:`    | minor | `feat: add avatar upload endpoint`  |
| `feat!:` or `BREAKING CHANGE:` | major | `feat!: redesign profiles response` |

semantic-release runs on `master` merges and produces a GitHub Release + git tag (`vX.Y.Z`).

## Release & Deployment Flow

The `release-and-promote.yml` workflow automates the full path from merge to staging:

```
master merge
  │
  ├─ 1. Build Docker image, push as  sha-<full-sha>
  │
  ├─ 2. Re-tag with integration tag:  int-<shortsha>-<YYYYMMDDHHmmss>
  │     (also updates floating tag `integration`)
  │
  ├─ 3. Wait: Argo CD Image Updater picks up int-* tag →
  │     writes back to gitops repo → Argo syncs → poll until Healthy
  │
  ├─ 4. Run semantic-release → produces version X.Y.Z
  │     (skips remaining steps if no releasable commits)
  │
  ├─ 5. Re-tag same digest as  X.Y.Z  (staging signal)
  │
  └─ 6. Wait: AIU picks up semver tag → gitops write-back → poll until Healthy
```

### Integration Tag Format

`int-<7-char-sha>-<YYYYMMDDHHmmss>` — lexicographically sortable so AIU's `semver` or `alphabetical` update strategy always picks the latest.

### Staging Semver Tag

A clean `X.Y.Z` tag (e.g. `1.3.0`) that only appears after integration passes. AIU in the staging environment watches for semver tags.

### Why Gate Staging on Integration Health?

Staging receives only builds that have been verified healthy in integration. This prevents broken images from cascading and keeps the staging environment stable for QA.

## Argo CD Image Updater (AIU) Integration

AIU is configured on each Argo Application to watch the ECR repository:

- **Integration app**: watches `int-*` tags (alphabetical/latest strategy)
- **Staging app**: watches semver tags (`~X.Y` or `X.*` constraint)

AIU uses **git write-back** to update the image tag in the gitops repository, which Argo CD then syncs.

## Required GitHub Actions Secrets

### AWS

| Secret                | Description                                      |
| --------------------- | ------------------------------------------------ |
| `AWS_ROLE_TO_ASSUME`  | IAM role ARN for OIDC federation (recommended)   |
| `AWS_REGION`          | e.g. `us-east-1`                                 |
| `ECR_REGISTRY`        | e.g. `123456789.dkr.ecr.us-east-1.amazonaws.com` |
| `ECR_REPOSITORY`      | e.g. `profiles-api`                              |

> Alternatively, use `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` instead of the role, and update the `configure-aws-credentials` step accordingly.

### Argo CD

| Secret                 | Description                                        |
| ---------------------- | -------------------------------------------------- |
| `ARGOCD_BASE_URL_INT`  | e.g. `https://argocd-npr-use2.playg.kotha.me`     |
| `ARGOCD_BASE_URL_STG`  | e.g. `https://argocd-npr-use1.playg.kotha.me`     |
| `ARGOCD_AUTH_TOKEN`    | Bearer token with read access to Applications      |
| `ARGOCD_APP_NAME_INT`  | e.g. `profiles-integration`                        |
| `ARGOCD_APP_NAME_STG`  | e.g. `profiles-staging`                            |

### GitHub

`GITHUB_TOKEN` is automatically provided by GitHub Actions and is used by semantic-release. If your repository requires a custom PAT for pushing tags or creating releases, set `GH_TOKEN` as a secret and reference it in the workflow.

## Scripts

### `tag-ecr.sh`

Re-tags an ECR image by fetching the manifest for a source tag and issuing `put-image` with a new tag. No rebuild needed.

```bash
bash services/profiles-api/scripts/tag-ecr.sh \
  <ECR_REGISTRY> <ECR_REPOSITORY> <SOURCE_TAG> <DEST_TAG> <AWS_REGION>
```

### `wait-argocd-app.sh`

Polls the Argo CD API until an Application reaches `Synced` + `Healthy` or a timeout is hit. Uses exponential backoff.

```bash
bash services/profiles-api/scripts/wait-argocd-app.sh \
  <ARGOCD_BASE_URL> <ARGOCD_AUTH_TOKEN> <APP_NAME> <TIMEOUT_SECONDS>
```
