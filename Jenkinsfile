pipeline {
    agent { label 'java' }
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
                sh "cp /var/lib/jenkins/workspace/Hello_Word_Pipeline/target/hello-world-war-1.0.0.war /opt/apache-tomcat-10.1.49/webapps"

            }
        }
    }
}
