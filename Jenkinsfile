pipeline {
  agent any

  environment {
    DOCKER_REG     = "docker.io/pavankumar99999"
    IMAGE_NAME     = "${DOCKER_REG}/hello-service"
    SSH_CREDENTIALS= 'deploy-ssh'      // Jenkins SSH credential id
    DOCKERHUB_CREDS= 'dockerhub-creds'
    TARGET_HOST    = "deploy@10.0.1.176"
    TARGET_SSH_PORT= "22"
    APP_NAME       = "hello-service"
    APP_PORT       = "8085"            // host port mapped to container 8080
    IMAGE_TAG      = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.substring(0,7)}"
  }

  stages {
    stage('Checkout') { steps { checkout scm } }

    stage('Build & Test') {
      steps {
        sh 'mvn -B -DskipTests=false clean package'
      }
    }

    stage('Build Docker Image') {
      steps {
        sh "docker build --pull -t ${IMAGE_NAME}:${IMAGE_TAG} ."
      }
    }

    stage('Login & Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: env.DOCKERHUB_CREDS, usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh 'echo $DH_PASS | docker login -u $DH_USER --password-stdin'
          sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
          sh 'docker logout'
        }
      }
    }

    stage('Deploy to Target (with health-check & rollback)') {
      steps {
        // either use sshagent (preferred) or withCredentials file method if sshagent plugin missing
        sshagent (credentials: [env.SSH_CREDENTIALS]) {
          sh """
            ssh -o StrictHostKeyChecking=no -p ${TARGET_SSH_PORT} ${TARGET_HOST} '
              set -e
              # ensure deploy script exists and is executable
              if [ ! -f /home/deploy/deploy.sh ]; then
                echo "/home/deploy/deploy.sh not found. Creating it..."
                cat > /home/deploy/deploy.sh <<'"'DEPLOYSCRIPT'"'
$(cat <<'INNER' | sed 's/^/                /'
#!/bin/bash
set -euo pipefail
APP_NAME="${1:-hello-service}"
IMAGE="${2:-}"
HOST_PORT="${3:-8085}"
if [ -z "$IMAGE" ]; then
  echo "Usage: $0 <app-name> <image:tag> [host-port]"
  exit 2
fi
PREV_IMAGE=""
if docker ps -a --format '{{.Names}}' | grep -q "^${APP_NAME}$"; then
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
    echo "Rollback successful. Previous image is healthy."
    exit 0
  else
    echo "Rollback also failed; please inspect container logs."
    docker logs --tail 200 ${APP_NAME} || true
    exit 3
  fi
else
  echo "No previous image found to rollback to. Please inspect container logs."
  docker logs --tail 200 ${APP_NAME} || true
  exit 4
fi
INNER
)
DEPLOYSCRIPT
                chmod 700 /home/deploy/deploy.sh
              fi

              # execute deploy script with image and host port
              /home/deploy/deploy.sh ${APP_NAME} ${IMAGE_NAME}:${IMAGE_TAG} ${APP_PORT}
            '
          """
        }
      }
    }
  }

  post {
    success {
      echo "Deployed ${IMAGE_NAME}:${IMAGE_TAG} to ${TARGET_HOST}"
    }
    failure {
      echo "Build or deploy failed"
    }
  }
}
