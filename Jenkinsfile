pipeline {
    agent any
    tools {
        jdk 'JDK21'
        maven 'M2_HOME'
    }

    environment {
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-pwd'  // ← CHANGER ICI
        DOCKER_IMAGE = 'oumaymahammami/country-service'
        DOCKER_REGISTRY = 'docker.io'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/oumaymahammami/country-service.git'
            }
        }

        stage('Build & Test') {
            steps {
                echo '🔧 Compiling and testing...'
                sh 'mvn clean compile'
                sh 'mvn test'
            }
            post {
                success {
                    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('Package') {
            steps {
                echo '📦 Packaging the application...'
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo '🐳 Building Docker image...'
                script {
                    // Build Docker image with build number tag
                    sh "docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} ."
                    // Also tag as latest
                    sh "docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest"
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo '📤 Pushing Docker image to Docker Hub...'
                script {
                    withCredentials([usernamePassword(
                        credentialsId: DOCKERHUB_CREDENTIALS_ID,
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh "echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin"
                        sh "docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                        sh "docker push ${DOCKER_IMAGE}:latest"
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                echo '🚀 Deploying application...'
                script {
                    // Stop and remove existing container
                    sh 'docker stop country-service || true'
                    sh 'docker rm country-service || true'

                    // Run new container - CORRECTION: utiliser le port 8082 comme dans votre Dockerfile
                    sh "docker run -d -p 8082:8082 --name country-service ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                }
            }
        }
    }

    post {
        always {
            echo '✅ Pipeline execution completed!'
            // Clean up Docker images to save space
            sh 'docker system prune -f || true'
        }
        success {
            echo '🎉 Pipeline succeeded! Application deployed successfully.'
            sh "echo 'Deployment successful: ${DOCKER_IMAGE}:${BUILD_NUMBER}'"
        }
        failure {
            echo '❌ Pipeline failed. Check console output for details.'
        }
    }
}