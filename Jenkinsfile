pipeline {
  agent any

  // Use the tool names you configured in "Global Tool Configuration"
  tools {
    jdk   'Java17'
    maven 'Maven3'
  }

  // Adjust these to your environment
  environment {
    REMOTE_USER = 'ubuntu'                // or ec2-user on Amazon Linux
    REMOTE_HOST = 'YOUR_SERVER_IP'        // <-- replace with your server's public IP/DNS
    TOMCAT_HOME = '/opt/tomcat10'         // '/opt/apache-tomcat-10.1.49' if that's what you installed
  }

  parameters {
    choice(name: 'MVN_GOAL',
           choices: ['clean package','package','install','compile'],
           description: 'Maven goal to run')
    booleanParam(name: 'SKIP_TESTS',
                 defaultValue: true,
                 description: 'Skip unit tests (-DskipTests)')
  }

  stages {

    stage('Checkout') {
      steps {
        // If the repo becomes private, add: credentialsId: 'github_https'
        git branch: 'master', url: 'https://github.com/Vinivinay52/hello-world-war.git'
      }
    }

    stage('Build WAR') {
      steps {
        sh '''
          set -e
          GOAL="${MVN_GOAL}"
          if [ "${SKIP_TESTS}" = "true" ]; then SKIP="-DskipTests"; else SKIP=""; fi
          echo "Running: mvn -B ${GOAL} ${SKIP}"
          mvn -B ${GOAL} ${SKIP}
          echo "Build output:"
          ls -l target
        '''
        archiveArtifacts artifacts: 'target/*.war', fingerprint: true
      }
    }

    stage('Deploy to Tomcat (SSH)') {
      steps {
        // Uses your SSH credential you created earlier
        sshagent(credentials: ['tomcat_ssh']) {
          sh '''
            set -e
            WAR="$(ls -1 target/*.war | head -n1)"
            echo "Deploying $WAR to ${REMOTE_USER}@${REMOTE_HOST}:${TOMCAT_HOME}/webapps/"
            scp -o StrictHostKeyChecking=no "$WAR" ${REMOTE_USER}@${REMOTE_HOST}:${TOMCAT_HOME}/webapps/

            echo "Restarting Tomcat..."
            ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "${TOMCAT_HOME}/bin/shutdown.sh || true"
            sleep 3
            ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "${TOMCAT_HOME}/bin/startup.sh"
          '''
        }
      }
    }
  }

  post {
    success {
      echo "✅ Deployment complete. Visit: http://${env.REMOTE_HOST}:8080/hello-world-war/"
    }
    failure {
      echo "❌ Pipeline failed — check the stage logs."
    }
  }
}
