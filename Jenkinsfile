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

        stage('Create Configuration') {
            steps {
                sh '''
                    echo "📁 Création de la configuration de production..."
                    
                    # Créer le fichier application-prod.yml avec la configuration COMPLÈTE
                    mkdir -p src/main/resources
                    cat > src/main/resources/application-prod.yml << 'EOF'
server:
  port: 8080

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus  # ✅ PROMETHEUS AJOUTÉ
      base-path: /actuator
    enabled-by-default: true
  endpoint:
    health:
      show-details: always
      enabled: true
      show-components: always
      group:
        readiness:
          include: readinessState,db,diskSpace
        liveness:
          include: livenessState,ping
    metrics:
      enabled: true
    prometheus:
      enabled: true
  health:
    livenessstate:
      enabled: true
    readinessstate:
      enabled: true

spring:
  security:
    basic:
      enable: false
  h2:
    console:
      enabled: true
      path: /h2-console
      settings:
        web-allow-others: true
  jpa:
    defer-datasource-initialization: true
    show-sql: true
    properties:
      hibernate:
        format_sql: true
  sql:
    init:
      mode: always
      platform: h2
  datasource:
    url: jdbc:h2:mem:testdb
    driverClassName: org.h2.Driver
    username: sa
    password: 

logging:
  level:
    com.demo.countryservice: DEBUG
    org.springframework.web: INFO
    org.hibernate: INFO
EOF
                    echo "✅ Fichier application-prod.yml créé avec configuration Prometheus complète"
                    cat src/main/resources/application-prod.yml
                '''
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
                        echo "project_lines_of_code{project=\\"country-service\\"} $LINES_OF_CODE" > code_metrics.prom
                        
                        # Compter les tests
                        TEST_COUNT=$(find . -name "*Test.java" | wc -l)
                        echo "project_test_count{project=\\"country-service\\"} $TEST_COUNT" >> code_metrics.prom
                        
                        # Métriques de compilation
                        echo "project_build_status{project=\\"country-service\\", job=\\"'$JOB_NAME_SANITIZED'\\", build=\\"'$BUILD_NUMBER'\\"} 1" >> code_metrics.prom
                        
                        echo "📊 Métriques générées:"
                        cat code_metrics.prom
                        
                        # Essayer d'envoyer à Pushgateway seulement s'il est disponible
                        if curl -s --connect-timeout 5 '$PUSHGATEWAY_URL' > /dev/null 2>&1; then
                            echo "🚀 Envoi des métriques à Pushgateway..."
                            curl -X POST --connect-timeout 10 --data-binary @code_metrics.prom "'$PUSHGATEWAY_URL'/metrics/job/country_service/instance/'$JOB_NAME_SANITIZED'"
                        else
                            echo "⚠️ Pushgateway non disponible, métriques sauvegardées localement"
                        fi
                    '''
                }
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: DOCKERHUB_CREDENTIALS_ID,
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh '''
                            echo "🐳 Construction de l'image Docker..."
                            echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
                            docker build -t $DOCKER_USERNAME/country-service:latest .
                            docker push $DOCKER_USERNAME/country-service:latest
                            echo "✅ Image Docker construite et poussée"
                        '''
                    }
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
                            # Exécuter Ansible avec les variables d'environnement
                            ansible-playbook playbookCICD.yml -e "docker_registry_username=$DOCKER_USERNAME docker_registry_password=$DOCKER_PASSWORD"
                        '''
                    }
                }
            }
        }

        stage('Fix Kubernetes Configuration') {
            steps {
                sh '''
                    echo "🔧 Correction de la configuration Kubernetes..."
                    
                    # Attendre que le déploiement soit créé
                    sleep 15
                    
                    # S'assurer que les variables d'environnement pour Prometheus sont correctes
                    kubectl patch deployment -n jenkins country-service -p '{
                        "spec": {
                            "template": {
                                "spec": {
                                    "containers": [{
                                        "name": "country-service",
                                        "env": [
                                            {
                                                "name": "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE",
                                                "value": "health,info,metrics,prometheus"
                                            },
                                            {
                                                "name": "MANAGEMENT_ENDPOINT_PROMETHEUS_ENABLED", 
                                                "value": "true"
                                            }
                                        ],
                                        "livenessProbe": {
                                            "httpGet": {
                                                "path": "/actuator/health",
                                                "port": 8080
                                            },
                                            "initialDelaySeconds": 90,
                                            "periodSeconds": 10,
                                            "timeoutSeconds": 5,
                                            "failureThreshold": 3
                                        },
                                        "readinessProbe": {
                                            "httpGet": {
                                                "path": "/actuator/health", 
                                                "port": 8080
                                            },
                                            "initialDelaySeconds": 60,
                                            "periodSeconds": 5,
                                            "timeoutSeconds": 3,
                                            "failureThreshold": 3
                                        }
                                    }]
                                }
                            }
                        }
                    }' || echo "⚠️ Deployment patch échoué"
                    
                    # Redémarrer le déploiement pour appliquer les changements
                    kubectl rollout restart deployment -n jenkins country-service
                    
                    echo "⏳ Attente de la stabilisation des pods..."
                    # Attendre que les pods soient prêts avec timeout
                    if kubectl wait --for=condition=ready pod -l app=country-service -n jenkins --timeout=180s; then
                        echo "✅ Pods stabilisés avec succès"
                    else
                        echo "⚠️ Timeout atteint, vérification de l'état des pods:"
                        kubectl get pods -n jenkins -l app=country-service
                        kubectl logs -n jenkins deployment/country-service --tail=20 || echo "Impossible de récupérer les logs"
                    fi
                '''
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
                        
                        # Importer un dashboard COMPLET pour country-service
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
                                                "legendFormat": "{{instance}}"
                                            }
                                        ],
                                        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
                                        "fieldConfig": {
                                            "defaults": {
                                                "color": {
                                                    "mode": "thresholds"
                                                },
                                                "thresholds": {
                                                    "steps": [
                                                        {"color": "red", "value": null},
                                                        {"color": "green", "value": 1}
                                                    ]
                                                }
                                            }
                                        }
                                    },
                                    {
                                        "id": 2,
                                        "title": "HTTP Requests Rate",
                                        "type": "graph",
                                        "targets": [
                                            {
                                                "expr": "rate(http_server_requests_seconds_count[5m])",
                                                "legendFormat": "{{method}} {{status}}"
                                            }
                                        ],
                                        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
                                    },
                                    {
                                        "id": 3, 
                                        "title": "JVM Memory Usage",
                                        "type": "graph",
                                        "targets": [
                                            {
                                                "expr": "jvm_memory_used_bytes{area=\\"heap\\"}",
                                                "legendFormat": "{{instance}}"
                                            }
                                        ],
                                        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16}
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

        stage('Verify Deployment & Metrics') {
            steps {
                sh '''
                    echo "🔍 Vérification du déploiement et des métriques..."
                    
                    # Vérifier l'état des pods
                    echo "📦 État des pods:"
                    kubectl get pods -n jenkins -l app=country-service
                    
                    # Vérifier l'application avec timeout
                    echo "📱 Test de l'application..."
                    timeout 60 bash -c 'until curl -f http://localhost:30008/actuator/health; do sleep 5; done' && echo "✅ Application accessible" || echo "❌ Application non accessible"
                    
                    # Vérifier les endpoints de métriques
                    echo "📊 Test des métriques Prometheus..."
                    if curl -s http://localhost:30008/actuator/prometheus | grep -q "jvm_memory_used_bytes"; then
                        echo "✅ Métriques Prometheus exposées avec succès"
                        curl -s http://localhost:30008/actuator/prometheus | head -5
                    else
                        echo "❌ Métriques Prometheus non disponibles"
                        curl -s http://localhost:30008/actuator/prometheus | head -5
                    fi

                    # Vérifier les services de monitoring
                    echo "📊 Test des services de monitoring..."
                    curl -s --connect-timeout 10 '$PROMETHEUS_URL' > /dev/null && echo "✅ Prometheus accessible" || echo "❌ Prometheus non accessible"
                    curl -s --connect-timeout 10 '$GRAFANA_URL' > /dev/null && echo "✅ Grafana accessible" || echo "❌ Grafana non accessible"
                    curl -s --connect-timeout 10 '$PUSHGATEWAY_URL' > /dev/null && echo "✅ Pushgateway accessible" || echo "❌ Pushgateway non accessible"
                    
                    # Vérifier que Prometheus scrape les métriques
                    echo "🔍 Vérification des targets Prometheus..."
                    curl -s '$PROMETHEUS_URL/api/v1/targets' | grep -A 10 -B 10 "country-service" || echo "⚠️ country-service non trouvé dans les targets Prometheus"
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
                            if curl -s --connect-timeout 5 http://localhost:30008/actuator/health > /dev/null; then
                                REQUEST_COUNT=$((REQUEST_COUNT + 1))
                                echo "✅ Requête $i réussie"
                            else
                                echo "❌ Requête $i échouée"
                            fi
                            sleep 0.1
                        done
                        
                        echo "✅ $REQUEST_COUNT requêtes réussies sur 20"
                        
                        # Envoyer des métriques de performance seulement si Pushgateway est disponible
                        if curl -s --connect-timeout 5 '$PUSHGATEWAY_URL' > /dev/null; then
                            cat << EOF | curl -X POST --connect-timeout 10 --data-binary @- "'$PUSHGATEWAY_URL'/metrics/job/load_test/instance/'$JOB_NAME_SANITIZED'"
# TYPE http_requests_total counter
http_requests_total{job="'$JOB_NAME_SANITIZED'", endpoint="health"} $REQUEST_COUNT
# TYPE http_success_rate gauge
http_success_rate{job="'$JOB_NAME_SANITIZED'"} $(echo "scale=2; $REQUEST_COUNT / 20" | bc)
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
                    
                    # Créer le fichier de métriques
                    cat > build_metrics.prom << EOF
# TYPE jenkins_build_info gauge
jenkins_build_info{job="${JOB_NAME_SANITIZED}", build_number="${BUILD_NUMBER}", status="${currentBuild.result}"} 1
# TYPE jenkins_build_duration_seconds gauge
jenkins_build_duration_seconds{job="${JOB_NAME_SANITIZED}", build_number="${BUILD_NUMBER}"} ${buildDuration}
# TYPE jenkins_build_status gauge
jenkins_build_status{job="${JOB_NAME_SANITIZED}", build_number="${BUILD_NUMBER}"} ${buildStatus}
EOF
                    
                    # Essayer d'envoyer à Pushgateway
                    if curl -s --connect-timeout 5 '${PUSHGATEWAY_URL}' > /dev/null; then
                        curl -X POST --connect-timeout 10 --data-binary @build_metrics.prom '${PUSHGATEWAY_URL}/metrics/job/jenkins/instance/${JOB_NAME_SANITIZED}' && echo "✅ Métriques finales envoyées" || echo "❌ Échec envoi métriques finales"
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
                    echo "📱 Application Health: http://localhost:30008/actuator/health"
                    echo "📊 Prometheus: http://localhost:9090"
                    echo "📈 Grafana: http://localhost:3000 (admin/admin)"
                    echo "🔔 Pushgateway: http://localhost:9091"
                    echo ""
                    echo "💡 COMMANDES DE VÉRIFICATION:"
                    echo "kubectl get pods -n jenkins"
                    echo "curl http://localhost:30008/actuator/prometheus"
                    echo "curl http://localhost:9090/api/v1/targets | grep country-service"
                '''
            }
        }
        failure {
            script {
                echo '❌ Pipeline échoué. Vérifiez les logs.'
                sh '''
                    echo "🔧 CONSEILS DE DÉPANNAGE:"
                    echo "1. Vérifiez les pods Kubernetes: kubectl get pods -n jenkins"
                    echo "2. Vérifiez les logs: kubectl logs -n jenkins deployment/country-service"
                    echo "3. Vérifiez les métriques: curl http://localhost:30008/actuator/prometheus"
                    echo "4. Vérifiez Prometheus targets: curl http://localhost:9090/api/v1/targets"
                    echo "5. Vérifiez la configuration: kubectl describe deployment -n jenkins country-service"
                '''
            }
        }
        unstable {
            echo '⚠️ Pipeline marqué comme instable'
        }
    }
}
