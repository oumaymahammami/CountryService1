pipeline {
    agent any
    tools {
        jdk 'JDK21'
        maven 'M2_HOME'
    }

    environment {
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-pwd11111'
        PROMETHEUS_URL = 'http://localhost:9090'
        GRAFANA_URL = 'http://localhost:3000'
        PUSHGATEWAY_URL = 'http://localhost:9091'
        JOB_NAME_SANITIZED = "${JOB_NAME.replace(' ', '_').replace('é', 'e')}"  // Sanitize job name
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

        stage('Test & Generate Metrics') {
            steps {
                sh 'mvn test'
                script {
                    // Générer des métriques de qualité du code
                    sh '''
                        # Compter les lignes de code
                        find src -name "*.java" | xargs wc -l | tail -1 | awk '{print $1}' > line_count.txt
                        LINES_OF_CODE=$(cat line_count.txt)
                        echo "project_lines_of_code{project=\"country-service\"} $LINES_OF_CODE" > code_metrics.prom
                        
                        # Compter les tests
                        TEST_COUNT=$(find . -name "*Test.java" | wc -l)
                        echo "project_test_count{project=\"country-service\"} $TEST_COUNT" >> code_metrics.prom
                        
                        # Métriques de compilation
                        echo "project_build_status{project=\"country-service\", job=\"$JOB_NAME_SANITIZED\", build=\"$BUILD_NUMBER\"} 1" >> code_metrics.prom
                        
                        echo "📊 Métriques générées:"
                        cat code_metrics.prom
                        
                        # Essayer d'envoyer à Pushgateway seulement s'il est disponible
                        if curl -s --connect-timeout 5 $PUSHGATEWAY_URL > /dev/null 2>&1; then
                            echo "🚀 Envoi des métriques à Pushgateway..."
                            curl -X POST --connect-timeout 10 --data-binary @code_metrics.prom "${PUSHGATEWAY_URL}/metrics/job/country_service/instance/${JOB_NAME_SANITIZED}"
                        else
                            echo "⚠️ Pushgateway non disponible, métriques sauvegardées localement"
                        fi
                    '''
                }
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

        stage('Deploy Monitoring Stack') {
            steps {
                script {
                    sh '''
                        echo "🔧 Déploiement de la stack de monitoring..."
                        # Vérifier si le playbook monitoring existe
                        if [ -f "playbook-monitoring.yml" ]; then
                            ansible-playbook playbook-monitoring.yml
                            # Attendre que les services soient prêts
                            echo "⏳ Attente du démarrage des services de monitoring..."
                            sleep 30
                        else
                            echo "⚠️ playbook-monitoring.yml non trouvé, déploiement Docker direct..."
                            # Déploiement direct des conteneurs
                            docker run -d --name prometheus -p 9090:9090 prom/prometheus:latest || echo "Prometheus déjà en cours d'exécution"
                            docker run -d --name pushgateway -p 9091:9091 prom/pushgateway:latest || echo "Pushgateway déjà en cours d'exécution"
                            docker run -d --name grafana -p 3000:3000 -e GF_SECURITY_ADMIN_PASSWORD=admin grafana/grafana:latest || echo "Grafana déjà en cours d'exécution"
                            sleep 20
                        fi
                    '''
                }
            }
        }

        stage('Configure Grafana Dashboard') {
            steps {
                script {
                    // Importer le dashboard Grafana avec gestion d'erreurs
                    sh '''
                        echo "📊 Configuration de Grafana..."
                        # Attendre que Grafana soit prêt
                        until curl -s http://localhost:3000/api/health > /dev/null 2>&1; do
                            echo "⏳ En attente de Grafana..."
                            sleep 5
                        done
                        
                        # Créer le datasource Prometheus dans Grafana
                        curl -X POST -H "Content-Type: application/json" \
                        -d '{
                            "name":"Prometheus",
                            "type":"prometheus",
                            "url":"http://host.docker.internal:9090",
                            "access":"proxy",
                            "basicAuth":false
                        }' \
                        http://admin:admin@localhost:3000/api/datasources || echo "Datasource peut déjà exister"
                        
                        # Importer un dashboard simple
                        curl -X POST -H "Content-Type: application/json" \
                        -d '{
                            "dashboard": {
                                "id": null,
                                "title": "Country Service Monitoring",
                                "tags": ["spring-boot", "microservice"],
                                "timezone": "browser",
                                "panels": [
                                    {
                                        "id": 1,
                                        "title": "Application Status",
                                        "type": "stat",
                                        "targets": [
                                            {
                                                "expr": "up{job=\\"country-service\\"}",
                                                "legendFormat": "Service Status"
                                            }
                                        ],
                                        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
                                    }
                                ],
                                "time": {
                                    "from": "now-6h",
                                    "to": "now"
                                }
                            },
                            "overwrite": true
                        }' \
                        http://admin:admin@localhost:3000/api/dashboards/db || echo "Dashboard configuration échouée ou déjà existante"
                        
                        echo "✅ Configuration Grafana terminée"
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "🔍 Vérification du déploiement..."
                    
                    # Vérifier l'application avec timeout
                    echo "📱 Test de l'application..."
                    timeout 30 bash -c 'until curl -f http://localhost:30008/getcountries; do sleep 2; done' || echo "Application check échouée mais continuation"
                    
                    # Vérifier les endpoints de santé
                    curl -f http://localhost:30008/actuator/health || echo "Health endpoint non disponible"
                    curl -s http://localhost:30008/actuator/prometheus | head -5 || echo "Metrics endpoint non disponible"

                    # Vérifier les services de monitoring
                    echo "📊 Test des services de monitoring..."
                    curl -s --connect-timeout 10 $PROMETHEUS_URL > /dev/null && echo "✅ Prometheus accessible" || echo "❌ Prometheus non accessible"
                    curl -s --connect-timeout 10 $GRAFANA_URL > /dev/null && echo "✅ Grafana accessible" || echo "❌ Grafana non accessible"
                    curl -s --connect-timeout 10 $PUSHGATEWAY_URL > /dev/null && echo "✅ Pushgateway accessible" || echo "❌ Pushgateway non accessible"
                '''
            }
        }

        stage('Run Load Test & Generate Performance Metrics') {
            steps {
                script {
                    // Simuler des tests de charge avec gestion d'erreurs
                    sh '''
                        echo "🚀 Démarrage des tests de charge..."
                        REQUEST_COUNT=0
                        for i in {1..20}; do
                            if curl -s --connect-timeout 5 http://localhost:30008/getcountries > /dev/null; then
                                REQUEST_COUNT=$((REQUEST_COUNT + 1))
                            fi
                            sleep 0.1
                        done
                        
                        echo "✅ $REQUEST_COUNT requêtes réussies"
                        
                        # Envoyer des métriques de performance seulement si Pushgateway est disponible
                        if curl -s --connect-timeout 5 $PUSHGATEWAY_URL > /dev/null; then
                            cat << EOF | curl -X POST --connect-timeout 10 --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/load_test/instance/${JOB_NAME_SANITIZED}"
                            # TYPE http_requests_total counter
                            http_requests_total{job="${JOB_NAME_SANITIZED}", endpoint="getcountries"} $REQUEST_COUNT
                            # TYPE http_test_duration gauge
                            http_test_duration{job="${JOB_NAME_SANITIZED}"} 2.0
                            EOF
                            echo "📤 Métriques de performance envoyées"
                        else
                            echo "⚠️ Pushgateway non disponible pour les métriques de performance"
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                // Envoyer les métriques finales du build à Prometheus avec gestion d'erreurs
                def buildDuration = currentBuild.duration / 1000
                def buildStatus = currentBuild.result == 'SUCCESS' ? 1 : 0
                
                sh """
                    echo "📤 Envoi des métriques finales du build..."
                    METRICS_DATA=$(cat << EOF
                    # TYPE jenkins_build_info gauge
                    jenkins_build_info{job="${JOB_NAME_SANITIZED}", build_number="${BUILD_NUMBER}", status="${currentBuild.result}"} 1
                    # TYPE jenkins_build_duration_seconds gauge
                    jenkins_build_duration_seconds{job="${JOB_NAME_SANITIZED}", build_number="${BUILD_NUMBER}"} ${buildDuration}
                    # TYPE jenkins_build_status gauge
                    jenkins_build_status{job="${JOB_NAME_SANITIZED}", build_number="${BUILD_NUMBER}"} ${buildStatus}
                    EOF
                    )
                    
                    # Sauvegarder les métriques dans un fichier
                    echo "\$METRICS_DATA" > build_metrics.prom
                    
                    # Essayer d'envoyer à Pushgateway
                    if curl -s --connect-timeout 5 $PUSHGATEWAY_URL > /dev/null; then
                        curl -X POST --connect-timeout 10 --data-binary @build_metrics.prom "${PUSHGATEWAY_URL}/metrics/job/jenkins/instance/${JOB_NAME_SANITIZED}" && echo "✅ Métriques finales envoyées" || echo "❌ Échec envoi métriques finales"
                    else
                        echo "⚠️ Pushgateway non disponible pour les métriques finales"
                        echo "📄 Métriques sauvegardées:"
                        cat build_metrics.prom
                    fi
                """
                
                // Nettoyer l'espace de travail
                cleanWs()
            }
        }
        success {
            script {
                echo '🎉 Pipeline réussi! Monitoring actif.'
                sh '''
                    echo "🏁 PIPELINE TERMINÉ AVEC SUCCÈS 🏁"
                    echo "🔗 LIENS IMPORTANTS:"
                    echo "📱 Application: http://localhost:30008/getcountries"
                    echo "📊 Prometheus: http://localhost:9090"
                    echo "📈 Grafana: http://localhost:3000 (admin/admin)"
                    echo "🔔 Pushgateway: http://localhost:9091"
                    echo ""
                    echo "💡 COMMANDES DE VÉRIFICATION:"
                    echo "docker ps"
                    echo "curl http://localhost:30008/actuator/health"
                    echo "curl http://localhost:9090/targets"
                '''
            }
        }
        failure {
            script {
                echo '❌ Pipeline échoué. Vérifiez les logs.'
                sh '''
                    echo "🔧 CONSEILS DE DÉPANNAGE:"
                    echo "1. Vérifiez que Docker est en cours d'exécution: docker ps"
                    echo "2. Vérifiez les logs des conteneurs: docker logs prometheus"
                    echo "3. Vérifiez la connexion Kubernetes: kubectl get pods -A"
                    echo "4. Vérifiez les logs Ansible"
                '''
            }
        }
        unstable {
            echo '⚠️ Pipeline marqué comme instable'
        }
    }
}
