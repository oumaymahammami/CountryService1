pipeline {
    agent any
    tools {
        jdk 'JDK21'
        maven 'M2_HOME'
    }

    environment {
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-pwd11111'
        DOCKERHUB_USERNAME = 'oumaymahammami'
        DOCKER_IMAGE = 'oumaymahammami/country-service'
        DOCKER_REGISTRY = 'docker.io'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/oumaymahammami/CountryService1.git'
            }
        }

        stage('Verify Files') {
            steps {
                echo '📁 Checking project structure...'
                sh 'pwd'
                sh 'ls -la'
                sh 'find . -name "pom.xml" -type f || echo "No POM file found"'
                sh 'find . -name "Dockerfile" -type f || echo "No Dockerfile found"'
            }
        }

        stage('Build & Test') {
            steps {
                echo '🔧 Compiling and testing...'
                sh 'mvn clean compile'
                sh 'mvn test -DskipTests'
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
                    withCredentials([string(
                        credentialsId: DOCKERHUB_CREDENTIALS_ID,
                        variable: 'DOCKER_PASSWORD'
                    )]) {
                        sh """
                            docker login -u $DOCKERHUB_USERNAME -p $DOCKER_PASSWORD
                            docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                            docker push ${DOCKER_IMAGE}:latest
                        """
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

                    // Run new container
                    sh "docker run -d -p 8082:8082 --name country-service ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                }
            }
        }
    }

    post {
        always {
            echo '✅ Pipeline execution completed!'
            // Clean up Docker images to save space
            sh 'docker system prune -f'
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
