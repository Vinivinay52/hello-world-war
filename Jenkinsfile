pipeline {
    agent none
    stages {
            stage ('hello-world-war') {
            parallel {
            stage ('checkout') {
                agent { label 'java' }
                steps {
                sh "rm -rf hello-world-war"
                sh "git clone https://github.com/Vinivinay52/hello-world-war"
            }
        }
         stage('build') {
            agent { label 'java' }
             steps {
                sh "mvn clean package"
            }
        }
         stage('deploy') {
             agent { label 'java' }
            steps {
                sh "sudo cp /home/slave1/workspace/Hello_Word_Pipeline/target/hello-world-war-1.0.0.war  /opt/apache-tomcat-10.1.49/webapps"

            }
        }
    }
}
}
}
