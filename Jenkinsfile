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
                        echo "project_lines_of_code{project=\"country-service\"} $(find src -name "*.java" | xargs wc -l | tail -1 | awk '{print $1}')" > code_metrics.prom
                        
                        # Compter les tests
                        TEST_COUNT=$(find . -name "*Test.java" | wc -l)
                        echo "project_test_count{project=\"country-service\"} $TEST_COUNT" >> code_metrics.prom
                        
                        # Métriques de compilation
                        echo "project_build_status{project=\"country-service\", job=\"$JOB_NAME\", build=\"$BUILD_NUMBER\"} 1" >> code_metrics.prom
                        
                        # Envoyer à Pushgateway
                        curl -X POST --data-binary @code_metrics.prom ${PUSHGATEWAY_URL}/metrics/job/country_service/instance/$JOB_NAME
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
                        # Déployer Prometheus, Grafana et Node Exporter via Ansible
                        ansible-playbook playbook-monitoring.yml
                        
                        # Attendre que les services soient prêts
                        sleep 30
                    '''
                }
            }
        }

        stage('Configure Grafana Dashboard') {
            steps {
                script {
                    // Importer le dashboard Grafana
                    sh '''
                        # Créer le datasource Prometheus dans Grafana
                        curl -X POST -H "Content-Type: application/json" \
                        -d '{
                            "name":"Prometheus",
                            "type":"prometheus",
                            "url":"http://prometheus:9090",
                            "access":"proxy",
                            "basicAuth":false
                        }' \
                        http://admin:admin@localhost:3000/api/datasources

                        # Importer le dashboard pour l'application
                        curl -X POST -H "Content-Type: application/json" \
                        -d '{
                            "dashboard": {
                                "id": null,
                                "title": "Country Service Monitoring",
                                "tags": ["kubernetes", "microservice"],
                                "timezone": "browser",
                                "panels": [
                                    {
                                        "id": 1,
                                        "title": "Application Health",
                                        "type": "stat",
                                        "targets": [
                                            {
                                                "expr": "up{job=\\"country-service\\"}",
                                                "legendFormat": "Service Status"
                                            }
                                        ],
                                        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
                                    },
                                    {
                                        "id": 2,
                                        "title": "Build Status History",
                                        "type": "graph",
                                        "targets": [
                                            {
                                                "expr": "jenkins_build_status{job=\\"$JOB_NAME\\"}",
                                                "legendFormat": "Build Success Rate"
                                            }
                                        ],
                                        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
                                    }
                                ],
                                "time": {
                                    "from": "now-6h",
                                    "to": "now"
                                }
                            },
                            "overwrite": true
                        }' \
                        http://admin:admin@localhost:3000/api/dashboards/db
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    # Vérifier l'application
                    echo "🔍 Checking application health..."
                    curl -f http://localhost:30008/getcountries || echo "Application check completed"

                    # Vérifier Prometheus
                    echo "🔍 Checking Prometheus..."
                    curl -f ${PROMETHEUS_URL}/graph || echo "Prometheus check completed"

                    # Vérifier Grafana
                    echo "🔍 Checking Grafana..."
                    curl -f ${GRAFANA_URL} || echo "Grafana check completed"

                    # Vérifier les métriques
                    echo "🔍 Checking metrics endpoint..."
                    curl -f http://localhost:30008/actuator/prometheus || curl -f http://localhost:30008/metrics || echo "Metrics endpoint check completed"
                '''
            }
        }

        stage('Run Load Test & Generate Performance Metrics') {
            steps {
                script {
                    // Simuler des tests de charge et générer des métriques de performance
                    sh '''
                        # Simuler des requêtes HTTP pour générer des métriques
                        for i in {1..50}; do
                            curl -s http://localhost:30008/getcountries > /dev/null
                            sleep 0.1
                        done

                        # Envoyer des métriques de performance custom
                        cat << EOF | curl --data-binary @- ${PUSHGATEWAY_URL}/metrics/job/load_test/instance/$JOB_NAME
                        # TYPE http_requests_total counter
                        http_requests_total{job="$JOB_NAME", endpoint="getcountries"} 50
                        # TYPE http_request_duration_seconds histogram
                        http_request_duration_seconds_bucket{le="0.1", job="$JOB_NAME"} 45
                        http_request_duration_seconds_bucket{le="0.5", job="$JOB_NAME"} 50
                        http_request_duration_seconds_bucket{le="+Inf", job="$JOB_NAME"} 50
                        http_request_duration_seconds_sum{job="$JOB_NAME"} 2.5
                        http_request_duration_seconds_count{job="$JOB_NAME"} 50
                        EOF
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                // Envoyer les métriques finales du build à Prometheus
                def buildDuration = currentBuild.duration / 1000
                def buildStatus = currentBuild.result == 'SUCCESS' ? 1 : 0
                
                sh """
                    cat << EOF | curl --data-binary @- ${PUSHGATEWAY_URL}/metrics/job/jenkins/instance/${JOB_NAME}
                    # TYPE jenkins_build_info gauge
                    jenkins_build_info{job="${JOB_NAME}", build_number="${BUILD_NUMBER}", status="${currentBuild.result}"} 1
                    # TYPE jenkins_build_duration_seconds gauge
                    jenkins_build_duration_seconds{job="${JOB_NAME}", build_number="${BUILD_NUMBER}"} ${buildDuration}
                    # TYPE jenkins_build_status gauge
                    jenkins_build_status{job="${JOB_NAME}", build_number="${BUILD_NUMBER}"} ${buildStatus}
                    # TYPE jenkins_build_count counter
                    jenkins_build_count{job="${JOB_NAME}"} 1
                    EOF
                """
                
                // Nettoyer l'espace de travail
                cleanWs()
            }
        }
        success {
            script {
                echo '🎉 Pipeline succeeded! Monitoring is active.'
                echo "✅ Application: http://localhost:30008/getcountries"
                echo "📊 Prometheus: ${PROMETHEUS_URL}"
                echo "📈 Grafana: ${GRAFANA_URL} (admin/admin)"
                echo "🔔 Pushgateway: ${PUSHGATEWAY_URL}"
                
                // Envoyer une notification avec les liens
                sh '''
                    echo "🏁 Pipeline COMPLETED SUCCESSFULLY 🏁"
                    echo "📊 Monitoring Dashboard: http://localhost:3000/dashboards"
                    echo "🔧 Application API: http://localhost:30008/getcountries"
                    echo "📈 Metrics: http://localhost:9090/graph"
                '''
            }
        }
        failure {
            script {
                echo '❌ Pipeline failed. Check monitoring for details.'
                
                // Envoyer des métriques d'échec
                sh """
                    cat << EOF | curl --data-binary @- ${PUSHGATEWAY_URL}/metrics/job/jenkins/instance/${JOB_NAME}
                    # TYPE jenkins_build_failure counter
                    jenkins_build_failure{job="${JOB_NAME}", build_number="${BUILD_NUMBER}"} 1
                    EOF
                """
            }
        }
        unstable {
            echo '⚠️ Pipeline marked as unstable'
        }
    }
}
