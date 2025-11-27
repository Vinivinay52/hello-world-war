pipeline {
    agent any
    stages {
            stage('Checkout') {
            steps {
                sh "rm -rf hello-world-war"
                sh "git clone https://github.com/Vinivinay52/hello-world-war"
            }
        }
         stage('build') {
            steps {
                sh "mvn clean package"
            }
        }
         stage('deploy') {
            steps {
                sh "sudo cp /var/lib/jenkins/workspace/hello-world-war/target/*.war /opt/apache-tomcat-10.1.19/webapps/"

            }
        }
    }
}
