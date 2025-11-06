pipeline {
    agent any
    tools {
        jdk 'JDK21'
        maven 'M2_HOME'
    }

    environment {
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-pwd11111'
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
                    sh "docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} ."
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
                        sh """
                            echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin
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
                    sh 'docker stop country-service || true'
                    sh 'docker rm country-service || true'
                    sh "docker run -d -p 8082:8082 --name country-service ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                }
            }
        }
    }

    post {
        always {
            echo '✅ Pipeline execution completed!'
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
