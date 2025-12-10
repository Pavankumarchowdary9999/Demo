#!/bin/bash
set -euo pipefail

APP_NAME="${1:-hello-service}"
IMAGE="${2:-}"
HOST_PORT="${3:-8085}"

if [ -z "$IMAGE" ]; then
  echo "Usage: $0 <app-name> <image:tag> [host-port]" >&2
  exit 2
fi

PREV_IMAGE=""
if docker ps -a --format '{{.Names}}' | grep -q "^${APP_NAME}\$"; then
  PREV_IMAGE=$(docker inspect --format='{{.Config.Image}}' ${APP_NAME} 2>/dev/null || echo "")
  echo "Previous image for ${APP_NAME}: ${PREV_IMAGE}"
fi

echo "Pulling new image: ${IMAGE}"
docker pull "${IMAGE}"

if docker ps -q --filter "name=${APP_NAME}" | grep -q . ; then docker stop ${APP_NAME} || true; fi
if docker ps -aq --filter "name=${APP_NAME}" | grep -q . ; then docker rm ${APP_NAME} || true; fi

docker run -d --name ${APP_NAME} -p ${HOST_PORT}:8080 --restart unless-stopped "${IMAGE}"

MAX_WAIT=45
SLEEP=3
ELAPSED=0
echo "Waiting up to ${MAX_WAIT}s for health endpoint..."
until curl -sf "http://127.0.0.1:${HOST_PORT}/health" >/dev/null 2>&1; do
  sleep ${SLEEP}
  ELAPSED=$((ELAPSED + SLEEP))
  echo "  waited ${ELAPSED}s..."
  if [ ${ELAPSED} -ge ${MAX_WAIT} ]; then
    echo "Health check failed after ${MAX_WAIT}s"
    break
  fi
done

if curl -sf "http://127.0.0.1:${HOST_PORT}/health" >/dev/null 2>&1; then
  echo "New container healthy."
  exit 0
fi

if [ -n "${PREV_IMAGE}" ]; then
  echo "Rolling back to previous image: ${PREV_IMAGE}"
  docker stop ${APP_NAME} || true
  docker rm ${APP_NAME} || true
  docker pull "${PREV_IMAGE}" || true
  docker run -d --name ${APP_NAME} -p ${HOST_PORT}:8080 --restart unless-stopped "${PREV_IMAGE}"
  sleep 5
  if curl -sf "http://127.0.0.1:${HOST_PORT}/health" >/dev/null 2>&1; then
    echo "Rollback successful."
    exit 0
  else
    echo "Rollback failed as well; inspect logs."
    docker logs --tail 200 ${APP_NAME} || true
    exit 3
  fi
else
  echo "No previous image found to rollback to. Check logs."
  docker logs --tail 200 ${APP_NAME} || true
  exit 4
fi
