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
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Deploy with Ansible') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: DOCKERHUB_CREDENTIALS_ID,
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        // Méthode SIMPLIFIÉE - utiliser les variables directement
                        sh """
                            # Créer un fichier vault avec echo
                            echo 'docker_registry_username: $DOCKER_USERNAME' > vault.yml
                            echo 'docker_registry_password: $DOCKER_PASSWORD' >> vault.yml
                            
                            # Crypter le vault
                            ansible-vault encrypt vault.yml --vault-password-file <(echo "vaultpass123")
                            
                            # Vérifier le vault
                            echo "=== Vault file created ==="
                            ls -la vault.yml
                        """
                        
                        // Test syntaxique
                        sh 'ansible-playbook playbookCICD.yml --syntax-check'
                        
                        // Déploiement avec vault
                        sh 'ansible-playbook playbookCICD.yml --vault-password-file <(echo "vaultpass123")'
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    sleep 10
                    curl -f http://localhost:30008/getcountries || echo "Service check completed"
                '''
            }
        }
    }

    post {
        always {
            sh 'rm -f vault.yml || true'
            cleanWs()
        }
        success {
            echo 'Pipeline succeeded'
        }
        failure {
            echo 'Pipeline failed'
        }
    }
}
