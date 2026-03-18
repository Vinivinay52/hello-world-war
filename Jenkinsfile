pipeline {
    agent any

    environment {
        APP_NAME        = "hello-world-war"
        DOCKER_IMAGE    = "thorvini/hello-world-war"
        IMAGE_TAG       = "${BUILD_NUMBER}"

        CHART_DIR       = "helm/hello-world-war"
        CHART_NAME      = "hello-world-war"

        JFROG_HOST      = "trialf5h0jz.jfrog.io"
        JFROG_HELM_REPO = "hello-world-war"
        JFROG_OCI_URL   = "oci://${JFROG_HOST}/${JFROG_HELM_REPO}"

        KUBE_NAMESPACE  = "default"
        RELEASE_NAME    = "hello-world-war"
        KUBECONFIG      = "/var/lib/jenkins/.kube/config"
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout Code') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/Vinivinay52/hello-world-war.git'
            }
        }

        stage('Verify Tools') {
            steps {
                sh '''
                    set -e
                    docker --version
                    helm version
                    kubectl version --client
                    python3 --version
                '''
            }
        }

        stage('Build WAR') {
            steps {
                sh '''
                    mvn clean package -DskipTests
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
                    docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest
                """
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS')]) {

                    sh """
                        echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
                        docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }

        stage('Update values.yaml') {
            steps {
                sh '''
                    python3 - << 'EOF'
import re

path = "helm/hello-world-war/values.yaml"

text = open(path).read()
text = re.sub(r'repository:.*', 'repository: thorvini/hello-world-war', text)
text = re.sub(r'tag:.*', 'tag: "' + str(${BUILD_NUMBER}) + '"', text)

open(path, "w").write(text)
EOF
                '''
            }
        }

        stage('Update Chart.yaml version') {
            steps {
                sh """
                    sed -i 's|version:.*|version: 0.1.${BUILD_NUMBER}|' ${CHART_DIR}/Chart.yaml
                    sed -i 's|appVersion:.*|appVersion: "${IMAGE_TAG}"|' ${CHART_DIR}/Chart.yaml
                """
            }
        }

        stage('Lint Chart') {
            steps {
                sh "helm lint ${CHART_DIR}"
            }
        }

        stage('Package Chart') {
            steps {
                sh """
                  mkdir -p packaged
                  rm -f packaged/*.tgz
                  helm package ${CHART_DIR} -d packaged
                """
            }
        }

        stage('Login to JFrog') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'jfrog-creds',
                    usernameVariable: 'JFROG_USER',
                    passwordVariable: 'JFROG_PASS')]) {

                    sh """
                        echo "${JFROG_PASS}" |
                        helm registry login ${JFROG_HOST} -u "${JFROG_USER}" --password-stdin
                    """
                }
            }
        }

        stage('Push Chart to JFrog OCI') {
            steps {
                sh """
                  helm push packaged/${CHART_NAME}-*.tgz ${JFROG_OCI_URL}
                """
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh """
                  export KUBECONFIG=${KUBECONFIG}
                  helm upgrade --install ${RELEASE_NAME} ${JFROG_OCI_URL}/${CHART_NAME} \
                    --namespace ${KUBE_NAMESPACE} \
                    --set image.repository=${DOCKER_IMAGE} \
                    --set image.tag=${IMAGE_TAG} \
                    --wait --debug
                """
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo "Hello World WAR App Deployed Successfully!"
        }
    }
}
