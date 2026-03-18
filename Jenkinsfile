pipeline {
    agent any

    environment {
        REMOTE_USER = 'ubuntu'
        REMOTE_HOST = '13.203.65.79'
        TOMCAT_HOME = '/opt/tomcat10'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'master', 
                    url: 'https://github.com/Vinivinay52/hello-world-war.git'
            }
        }

        stage('Check Java & Maven') {
            steps {
                sh '''
                    echo "Checking Java & Maven on Jenkins agent..."
                    java -version
                    mvn -version
                '''
            }
        }

        stage('Build WAR') {
            steps {
                sh '''
                    echo "Building WAR..."
                    mvn clean package -DskipTests
                    ls -l target
                '''
            }
        }

        stage('Deploy to Tomcat') {
            steps {
                sshagent(['tomcat_ssh']) {
                    sh '''
                        echo "Copying WAR to Remote Server..."
                        WAR_FILE=$(ls target/*.war | head -n1)

                        scp -o StrictHostKeyChecking=no "$WAR_FILE" ${REMOTE_USER}@${REMOTE_HOST}:${TOMCAT_HOME}/webapps/

                        echo "Restarting Tomcat..."
                        ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "${TOMCAT_HOME}/bin/shutdown.sh || true"
                        sleep 3
                        ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "${TOMCAT_HOME}/bin/startup.sh"

                        echo "Deployment Completed."
                    '''
                }
            }
        }
    }
}
