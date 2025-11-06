pipeline {
    agent any
    tools {
        jdk 'JDK21'
        maven 'M2_HOME'
    }

    environment {
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-pwd11111'
        DOCKER_IMAGE = 'oumayma511/country-service'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/oumaymahammami/CountryService1.git'
            }
        }

        stage('Build & Package') {
            steps {
                echo '🔧 Building and packaging...'
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Deploy with Ansible') {
            steps {
                echo '🚀 Deploying with Ansible...'
                script {
                    withCredentials([usernamePassword(
                        credentialsId: DOCKERHUB_CREDENTIALS_ID,
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        // Mettre à jour le playbook avec les credentials actuels
                        sh """
                            sed -i 's/docker_registry_username:.*/docker_registry_username: \"\${DOCKER_USERNAME}\"/' playbookCICD.yml
                            sed -i 's/docker_registry_password:.*/docker_registry_password: \"\${DOCKER_PASSWORD}\"/' playbookCICD.yml
                        """
                        
                        // Test syntaxique
                        sh 'ansible-playbook playbookCICD.yml --syntax-check'
                        
                        // Dry run
                        sh 'ansible-playbook playbookCICD.yml --check'
                        
                        // Déploiement réel
                        sh 'ansible-playbook playbookCICD.yml'
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                echo '✅ Verifying deployment...'
                sh '''
                    sleep 30
                    curl -f http://localhost:30008/getcountries || echo "Service might need more time to start"
                '''
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo '🎉 Success! Application deployed with Ansible pipeline.'
        }
        failure {
            echo '❌ Pipeline failed. Check logs for details.'
        }
    }
}
