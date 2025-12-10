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
    // Bind the SSH private key credential to a temporary file $SSH_KEY
    withCredentials([sshUserPrivateKey(credentialsId: 'deploy-ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
      // ensure deploy script exists in workspace (you should add deploy.sh to repo or generate it)
      // Copy the local workspace file deploy.sh to remote and run it
      sh """
        chmod 600 "$SSH_KEY"
        # Copy deploy.sh from workspace to remote target (using ssh + cat)
        cat deploy.sh | ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" -p ${TARGET_SSH_PORT} ${TARGET_HOST} 'cat > /home/deploy/deploy.sh && chmod 700 /home/deploy/deploy.sh'
        # Execute the deploy script remotely
        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" -p ${TARGET_SSH_PORT} ${TARGET_HOST} "/home/deploy/deploy.sh ${APP_NAME} ${IMAGE_NAME}:${IMAGE_TAG} ${APP_PORT}"
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
