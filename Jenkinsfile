pipeline {
    agent none
    parameters {
string(name: 'cmd', defaultValue: '', description: 'A sample string parameter')
booleanParam(name: 'SAMPLE_BOOLEAN', defaultValue: true, description: 'A boolean parameter')
choice(name: 'cmd1', choices: ['package', 'install', 'compile'], description: 'Choose one option')
}
    stages {
            stage ('hello-world-war') {
            parallel {
            stage ('checkout') {
                agent { label 'java' }
                steps {
                    withCredentials([
            usernamePassword(credentialsId: '8c6c682c-68e8-41e6-937b-ec240a7a07a5',
                     usernameVariable: 'Vinay_USERNAME',
                     passwordVariable: 'Vinay_PASSWORD'),
            sshUserPrivateKey(credentialsId: 'a905781f-db2a-4e12-af68-9b8d2b7890fa',
                      keyFileVariable: 'KEY_FILE',
                      usernameVariable: 'SSH_USER')
]) {

                sh "rm -rf hello-world-war"
                sh "git clone https://github.com/Vinivinay52/hello-world-war"
            }
        }
        }
         stage('build') {
            agent { label 'java' }
             steps {
                sh "mvn $cmd $cmd1"
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

