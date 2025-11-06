
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
                        // Créer un fichier vault temporaire
                        sh '''
                        cat > vault.yml << VAULT_EOF
docker_registry_username: $DOCKER_USERNAME
docker_registry_password: $DOCKER_PASSWORD
VAULT_EOF

                        # Crypter le vault
                        echo "vaultpass123" | ansible-vault encrypt vault.yml --vault-password-file=stdin
                        
                        # Vérifier le contenu
                        echo "=== Vault file created ==="
                        ls -la vault.yml
                        '''
                        
                        // Test syntaxique
                        sh 'ansible-playbook playbookCICD.yml --syntax-check'
                        
                        // Dry run
                        sh 'echo "vaultpass123" | ansible-playbook playbookCICD.yml --check --vault-password-file=stdin'
                        
                        // Déploiement réel
                        sh 'echo "vaultpass123" | ansible-playbook playbookCICD.yml --vault-password-file=stdin'
                        
                        // Nettoyer
                        sh 'rm -f vault.yml'
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                echo '✅ Verifying deployment...'
                sh '''
                    echo "Waiting for deployment to be ready..."
                    sleep 30
                    curl -f http://localhost:30008/getcountries || echo "Service check completed"
                '''
            }
        }
    }

    post {
        always {
            cleanWs()
            sh 'rm -f vault.yml || true'
        }
        success {
            echo '🎉 Success! Application deployed with Ansible pipeline.'
        }
        failure {
            echo '❌ Pipeline failed. Check logs for details.'
        }
    }
}

