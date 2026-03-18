pipeline {
    agent any

    environment {
        APP_NAME        = "hello-world-war"
        DOCKER_IMAGE    = "thorvini/hello-world-war"
        IMAGE_TAG       = "${BUILD_NUMBER}"

        CHART_DIR       = "ello‑world‑war repo/helm/hello-world-war"
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
                git branch: 'master',
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
                    set -e
                    mvn clean package -DskipTests
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    set -e
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
                        set -e
                        echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
                        docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout || true
                    """
                }
            }
        }

        /**************  FIXED STAGE (Variant A: Python reads env safely)  **************/
        stage('Update values.yaml') {
            steps {
                withEnv([
                    "CHART_DIR=${CHART_DIR}",
                    "DOCKER_IMAGE=${DOCKER_IMAGE}",
                    "IMAGE_TAG=${IMAGE_TAG}",
                    "WORKSPACE_DIR=${WORKSPACE}"
                ]) {
                    sh '''
                        set -e
                        echo "===== Debug Workspace ====="
                        pwd
                        ls -la
                        find . -name values.yaml || true

                        # Single-quoted heredoc: prevents Groovy/shell interpolation of ${...}
                        python3 - <<'PY'
from pathlib import Path
import os, re

chart_dir = os.environ["CHART_DIR"]
repo      = os.environ["DOCKER_IMAGE"]
# Fall back to BUILD_NUMBER or 'latest' if IMAGE_TAG not set
tag       = os.environ.get("IMAGE_TAG") or os.environ.get("BUILD_NUMBER","latest")

p = Path(chart_dir) / "values.yaml"
print("Using file:", p)
if not p.exists():
    raise FileNotFoundError("values.yaml not found at: " + str(p))

text = p.read_text()

def upsert(pattern, replacement, text):
    if re.search(pattern, text, flags=re.M):
        return re.sub(pattern, replacement, text, flags=re.M)
    # If the key doesn't exist, try to append inside 'image:' block
    if 'image:' in text:
        return re.sub(r'(^image:\\s*$)',
                      r"\\1\\n  repository: " + repo + "\\n  tag: \\"" + tag + "\\"\\n  pullPolicy: Always",
                      text, flags=re.M)
    # If no image block at all, add one at the end
    return text + "\\nimage:\\n  repository: " + repo + "\\n  tag: \\"" + tag + "\\"\\n  pullPolicy: Always\\n"

# Ensure/update the three keys
text = upsert(r'^\\s*repository:\\s*.*$', '  repository: ' + repo, text)
text = upsert(r'^\\s*tag:\\s*.*$',        '  tag: "' + tag + '"', text)
text = upsert(r'^\\s*pullPolicy:\\s*.*$', '  pullPolicy: Always', text)

p.write_text(text)
print("values.yaml updated successfully")
PY

                        echo "===== Updated values.yaml ====="
                        cat "${CHART_DIR}/values.yaml"
                    '''
                }
            }
        }
        /**************  END FIXED STAGE  **************/

        stage('Update Chart.yaml version') {
            steps {
                sh """
                    set -e
                    sed -i 's|^version:.*|version: 0.1.${BUILD_NUMBER}|' ${CHART_DIR}/Chart.yaml
                    sed -i 's|^appVersion:.*|appVersion: "${IMAGE_TAG}"|' ${CHART_DIR}/Chart.yaml

                    echo "===== Updated Chart.yaml ====="
                    cat ${CHART_DIR}/Chart.yaml
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
                  set -e
                  mkdir -p packaged
                  rm -f packaged/*.tgz
                  helm package ${CHART_DIR} -d packaged

                  echo "===== Packaged Chart ====="
                  ls -lh packaged
                """
            }
        }

        stage('Login to JFrog') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'jfrog-creds',
                    usernameVariable: 'JFROG_USER',
                    passwordVariable: 'JFROG_PASS')]) {

                    sh """
                        set -e
                        echo "${JFROG_PASS}" | helm registry login ${JFROG_HOST} -u "${JFROG_USER}" --password-stdin
                    """
                }
            }
        }

        stage('Push Chart to JFrog OCI') {
            steps {
                sh """
                  set -e
                  CHART_PKG=\$(ls packaged/${CHART_NAME}-*.tgz | head -n 1)
                  if [ -z "\$CHART_PKG" ]; then echo "ERROR: No chart package found"; exit 2; fi
                  echo "Pushing: \$CHART_PKG -> ${JFROG_OCI_URL}"
                  helm push "\$CHART_PKG" ${JFROG_OCI_URL}
                """
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh """
                  set -e
                  export KUBECONFIG=${KUBECONFIG}

                  CHART_VERSION=\$(grep '^version:' ${CHART_DIR}/Chart.yaml | awk '{print \$2}')

                  echo "===== Deploying ====="
                  echo "Chart: ${CHART_NAME}  Version: \$CHART_VERSION"
                  echo "Image: ${DOCKER_IMAGE}:${IMAGE_TAG}"

                  helm upgrade --install ${RELEASE_NAME} ${JFROG_OCI_URL}/${CHART_NAME} \
                    --version \$CHART_VERSION \
                    --namespace ${KUBE_NAMESPACE} \
                    --create-namespace \
                    --set image.repository=${DOCKER_IMAGE} \
                    --set image.tag=${IMAGE_TAG} \
                    --set image.pullPolicy=Always \
                    --wait --atomic --debug

                  echo "===== Pods ====="
                  kubectl get pods -n ${KUBE_NAMESPACE}
                  echo "===== Services ====="
                  kubectl get svc -n ${KUBE_NAMESPACE}
                """
            }
        }
    }

    post {
        always {
            sh "helm registry logout ${JFROG_HOST} || true"
            cleanWs()
        }
        success {
            echo "Hello World WAR App Deployed Successfully!"
        }
        failure {
            echo "FAILED: Check stage logs above."
        }
    }
}
