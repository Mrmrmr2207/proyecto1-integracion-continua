// Pipeline declarativo - Entrega 2 (Semana 5) - Integracion Continua
// Jenkins como gestor de integracion continua del proyecto API Flask + PostgreSQL.
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        API_URL = 'http://localhost:5000'
    }

    stages {
        stage('Obtener codigo') {
            steps {
                checkout scm
                sh 'git log -1 --oneline'
            }
        }

        stage('Validar estructura') {
            steps {
                sh 'test -f docker-compose.yml'
                sh 'test -f app/Dockerfile'
                sh 'test -f app/app.py'
                sh 'test -f db/init.sql'
                sh 'test -f .env.example'
                sh 'cp .env.example .env'
                sh 'docker --version && docker compose version'
                sh 'docker compose config --quiet && echo "docker-compose.yml valido"'
            }
        }

        stage('Construir e iniciar servicios') {
            steps {
                sh 'docker compose up --build -d'
                sh 'docker compose ps'
            }
        }

        stage('Verificar API') {
            steps {
                sh '''
                    for intento in $(seq 1 30); do
                        if curl -fsS "$API_URL/health" -o health.json; then
                            echo "API disponible en el intento $intento"
                            cat health.json; echo
                            grep -q '"status":"ok"' health.json
                            grep -q '"database":"up"' health.json
                            exit 0
                        fi
                        echo "Esperando la API... intento $intento"
                        sleep 2
                    done
                    echo "La API no estuvo disponible dentro del tiempo esperado"
                    exit 1
                '''
                sh 'curl -fsS "$API_URL/tareas" | tee tareas.json; echo'
                sh '''
                    curl -fsS -X POST "$API_URL/tareas" \
                      -H "Content-Type: application/json" \
                      -d "{\\"titulo\\":\\"Prueba Jenkins build ${BUILD_NUMBER}\\"}" | tee tarea_creada.json; echo
                    grep -q "Prueba Jenkins build ${BUILD_NUMBER}" tarea_creada.json
                '''
            }
        }

        stage('Registrar resultado') {
            steps {
                archiveArtifacts artifacts: 'health.json,tareas.json,tarea_creada.json', fingerprint: true
            }
        }
    }

    post {
        always {
            sh 'docker compose ps || true'
            sh 'docker compose logs --no-color || true'
        }
        success { echo 'Pipeline finalizado: verificaciones satisfactorias.' }
        failure { echo 'Pipeline fallido: revisar la etapa y los registros.' }
        cleanup { sh 'docker compose down || true' }
    }
}
