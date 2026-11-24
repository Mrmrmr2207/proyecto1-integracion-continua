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
                sh 'bash jenkins/pruebas_api.sh'
            }
        }

        stage('Registrar resultado') {
            steps {
                archiveArtifacts artifacts: 'health.json,tareas.json,tarea_creada.json,reports/*.xml', fingerprint: true
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'reports/*.xml'
            sh 'docker compose ps || true'
            sh 'docker compose logs --no-color || true'
        }
        success { echo 'Pipeline finalizado: verificaciones satisfactorias.' }
        failure { echo 'Pipeline fallido: revisar la etapa y los registros.' }
        cleanup { sh 'docker compose down || true' }
    }
}
