pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                sh "rm -rf hello-world-war"
                sh "git clone https://github.com/Vinivinay52/hello-world-war"
            }
        }
    }
}
