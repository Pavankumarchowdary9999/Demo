pipeline {
  agent any

  environment {
    DOCKER_REG = "docker.io/pavankumar99999"
    IMAGE_NAME = "${DOCKER_REG}/hello-service"
    SSH_CREDENTIALS = 'deploy-ssh'          // Jenkins SSH credential id
    DOCKERHUB_CREDS = 'dockerhub-creds'    // Jenkins DockerHub username/password
    TARGET_HOST = "deploy@13.127.8.25"  // user@target_ip
    TARGET_SSH_PORT = "22"
    APP_NAME = "hello-service"
    APP_PORT = "8085"
    IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.substring(0,7)}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

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

    stage('Deploy to Target') {
      steps {
        // Uses ssh-agent plugin: adds ssh private-key to ssh-agent for the duration of the block
        sshagent (credentials: [env.SSH_CREDENTIALS]) {
          // Pull, stop, remove, run new container
          sh """
            ssh -o StrictHostKeyChecking=no -p ${TARGET_SSH_PORT} ${TARGET_HOST} '
              set -e
              docker pull ${IMAGE_NAME}:${IMAGE_TAG}
              # stop old container if exists
              if docker ps -q --filter "name=${APP_NAME}" | grep -q . ; then
                docker stop ${APP_NAME} || true
              fi
              if docker ps -aq --filter "name=${APP_NAME}" | grep -q . ; then
                docker rm ${APP_NAME} || true
              fi
              # Run new container (adjust env/volumes as needed)
              docker run -d --name ${APP_NAME} -p ${APP_PORT}:8080 --restart unless-stopped ${IMAGE_NAME}:${IMAGE_TAG}
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
