pipeline {
    agent { label "java" }
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
                sh "sudo cp /var/lib/jenkins/workspace/hello-world-war/target/hello-world-war-1.0.0.war /opt/apache-tomcat-10.1.19/webapps/"
            }
        }
    }
}
