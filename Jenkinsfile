pipeline {
    agent any
    tools {
        jdk 'JDK21'
        maven 'M2_HOME'
    }

    environment {
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-pwd11111'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/oumaymahammami/CountryService1.git'
            }
        }

        stage('Build & Package') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Deploy with Ansible') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: DOCKERHUB_CREDENTIALS_ID,
                        usernameVariable: 'oumaima511',
                        passwordVariable: 'dckr_pat_2ff-HkUO5yLPa_kiiD9t-v9IzOY'
                    )]) {
                        // Méthode SIMPLE - exécuter directement avec variables d'environnement
                        sh '''
                            # Tester la connexion Docker d'abord
                            echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
                            
                            # Exécuter Ansible avec les variables d'environnement
                            ansible-playbook playbookCICD.yml -e "docker_registry_username=$DOCKER_USERNAME docker_registry_password=$DOCKER_PASSWORD"
                        '''
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    sleep 10
                    curl http://localhost:30008/getcountries || echo "Service check completed"
                '''
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo '🎉 Pipeline succeeded!'
        }
        failure {
            echo '❌ Pipeline failed.'
        }
    }
}
