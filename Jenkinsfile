pipeline {
    agent any

    environment {
        APP_NAME        = "hello-world-war"

        // Docker image coordinates
        DOCKER_IMAGE    = "thorvini/hello-world-war"
        IMAGE_TAG       = "${BUILD_NUMBER}"

        // Default chart location (we will auto-resolve real path at runtime)
        CHART_DIR       = "helm/hello-world-war"
        CHART_NAME      = "hello-world-war"

        // JFrog Artifactory Helm (OCI)
        JFROG_HOST      = "trialf5h0jz.jfrog.io"
        JFROG_HELM_REPO = "hello-world-war"
        JFROG_OCI_URL   = "oci://${JFROG_HOST}/${JFROG_HELM_REPO}"

        // Kubernetes
        KUBE_NAMESPACE  = "default"
        RELEASE_NAME    = "hello-world-war"
        KUBECONFIG      = "/var/lib/jenkins/.kube/config"
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {

        /* Jenkins also does a "Declarative: Checkout SCM" automatically.
           Keeping an explicit checkout stage for clarity and idempotence. */
        stage('Checkout Code') {
            steps {
                git branch: 'master',
                    url: 'https://github.com/Vinivinay52/hello-world-war.git'
            }
        }

        /* NEW: Resolve the real chart directory at runtime, regardless of
                 the parent folder having spaces or non-ASCII hyphens. */
        stage('Locate chart dir') {
            steps {
                script {
                    def found = sh(returnStdout: true, label: 'find chart dir', script: '''
                        set -e
                        # find a values.yaml for the hello-world-war chart anywhere in repo
                        p=$(find . -type f -path "*/helm/hello-world-war/values.yaml" -print -quit)
                        if [ -n "$p" ]; then
                          dirname "$(dirname "$p")"   # => .../helm/hello-world-war
                        fi
                    ''').trim()

                    if (!found) {
                        error "Could not locate values.yaml for hello-world-war chart. Expected pattern: */helm/hello-world-war/values.yaml"
                    }

                    // strip leading "./" if present
                    env.CHART_DIR_RESOLVED = found.replaceFirst(/^\\.\//, '')
                    echo "Resolved chart dir: ${env.CHART_DIR_RESOLVED}"
                }
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
                    // Use single-quoted shell so there is no Groovy interpolation of secrets
                    sh '''
                        set -e
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push '"$DOCKER_IMAGE"':'"$IMAGE_TAG"'
                        docker push '"$DOCKER_IMAGE"':latest
                        docker logout || true
                    '''
                }
            }
        }

        /* FIXED: Update values.yaml safely (Python reads env via os.environ) */
        stage('Update values.yaml') {
            steps {
                withEnv([
                    "CHART_DIR_RESOLVED=${CHART_DIR_RESOLVED}",
                    "DOCKER_IMAGE=${DOCKER_IMAGE}",
                    "IMAGE_TAG=${IMAGE_TAG}",
                    "WORKSPACE_DIR=${WORKSPACE}"
                ]) {
                    sh '''
                        set -e
                        echo "===== Debug Workspace ====="
                        pwd
                        ls -la
                        echo "Resolved chart dir: ${CHART_DIR_RESOLVED}"
                        [ -f "${CHART_DIR_RESOLVED}/values.yaml" ] || { echo "values.yaml not found at ${CHART_DIR_RESOLVED}"; exit 2; }

                        # Single-quoted heredoc so no Groovy/shell interpolation is applied inside Python
                        python3 - <<'PY'
from pathlib import Path
import os, re

chart_dir = os.environ["CHART_DIR_RESOLVED"]
repo      = os.environ["DOCKER_IMAGE"]
tag       = os.environ.get("IMAGE_TAG") or os.environ.get("BUILD_NUMBER","latest")

p = Path(chart_dir) / "values.yaml"
print("Using file:", p)
if not p.exists():
    raise FileNotFoundError(f"values.yaml not found at: {p}")

text = p.read_text()

def upsert(pattern, replacement, text):
    if re.search(pattern, text, flags=re.M):
        return re.sub(pattern, replacement, text, flags=re.M)
    # If a key is missing, try to insert under 'image:' block; otherwise append a new block
    if 'image:' in text:
        return re.sub(r'(^image:\\s*$)',
                      r"\\1\\n  repository: " + repo + "\\n  tag: \\"" + tag + "\\"\\n  pullPolicy: Always",
                      text, flags=re.M)
    return text + "\\nimage:\\n  repository: " + repo + "\\n  tag: \\"" + tag + "\\"\\n  pullPolicy: Always\\n"

text = upsert(r'^\\s*repository:\\s*.*$', '  repository: ' + repo, text)
text = upsert(r'^\\s*tag:\\s*.*$',        '  tag: "' + tag + '"', text)
text = upsert(r'^\\s*pullPolicy:\\s*.*$', '  pullPolicy: Always', text)

p.write_text(text)
print("values.yaml updated successfully")
PY

                        echo "===== Updated values.yaml ====="
                        sed -n '1,120p' "${CHART_DIR_RESOLVED}/values.yaml"
                    '''
                }
            }
        }

        stage('Update Chart.yaml version') {
            steps {
                sh """
                    set -e
                    sed -i 's|^version:.*|version: 0.1.${BUILD_NUMBER}|' "${CHART_DIR_RESOLVED}/Chart.yaml"
                    sed -i 's|^appVersion:.*|appVersion: \\"${IMAGE_TAG}\\"|' "${CHART_DIR_RESOLVED}/Chart.yaml"

                    echo "===== Updated Chart.yaml ====="
