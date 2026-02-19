#!/usr/bin/env bash
set -euo pipefail

# Polls an Argo CD Application until it is Synced + Healthy or timeout.
#
# Usage:
#   wait-argocd-app.sh <ARGOCD_BASE_URL> <ARGOCD_AUTH_TOKEN> <APP_NAME> <TIMEOUT_SECONDS>

ARGOCD_BASE_URL="${1:?ARGOCD_BASE_URL required}"
ARGOCD_AUTH_TOKEN="${2:?ARGOCD_AUTH_TOKEN required}"
APP_NAME="${3:?APP_NAME required}"
TIMEOUT_SECONDS="${4:-300}"

INTERVAL=10
MAX_INTERVAL=60
ELAPSED=0

echo "Waiting for Argo CD app '${APP_NAME}' to be Synced+Healthy (timeout ${TIMEOUT_SECONDS}s)..."

while true; do
  RESPONSE=$(curl -sf -H "Authorization: Bearer ${ARGOCD_AUTH_TOKEN}" \
    "${ARGOCD_BASE_URL}/api/v1/applications/${APP_NAME}" 2>&1) || {
    echo "  [${ELAPSED}s] API call failed, retrying..."
    sleep "${INTERVAL}"
    ELAPSED=$((ELAPSED + INTERVAL))
    if [ "${ELAPSED}" -ge "${TIMEOUT_SECONDS}" ]; then
      echo "ERROR: Timed out after ${TIMEOUT_SECONDS}s waiting for ${APP_NAME}"
      exit 1
    fi
    INTERVAL=$(( INTERVAL * 2 > MAX_INTERVAL ? MAX_INTERVAL : INTERVAL * 2 ))
    continue
  }

  SYNC_STATUS=$(echo "${RESPONSE}" | jq -r '.status.sync.status // "Unknown"')
  HEALTH_STATUS=$(echo "${RESPONSE}" | jq -r '.status.health.status // "Unknown"')

  echo "  [${ELAPSED}s] sync=${SYNC_STATUS}  health=${HEALTH_STATUS}"

  if [ "${SYNC_STATUS}" = "Synced" ] && [ "${HEALTH_STATUS}" = "Healthy" ]; then
    echo "App '${APP_NAME}' is Synced and Healthy."
    exit 0
  fi

  sleep "${INTERVAL}"
  ELAPSED=$((ELAPSED + INTERVAL))

  if [ "${ELAPSED}" -ge "${TIMEOUT_SECONDS}" ]; then
    echo "ERROR: Timed out after ${TIMEOUT_SECONDS}s waiting for ${APP_NAME}"
    echo "  Last status: sync=${SYNC_STATUS}  health=${HEALTH_STATUS}"
    exit 1
  fi

  INTERVAL=$(( INTERVAL * 2 > MAX_INTERVAL ? MAX_INTERVAL : INTERVAL * 2 ))
done
