pipeline {
    agent any

    environment {
        APP_NAME        = "hello-world-war"

        // Docker image
        DOCKER_IMAGE    = "thorvini/hello-world-war"
        IMAGE_TAG       = "${BUILD_NUMBER}"

        // Default chart location (we auto-resolve actual path at runtime)
        CHART_DIR       = "helm/hello-world-war"
        CHART_NAME      = "hello-world-war"

        // JFrog Helm OCI
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

        stage("Checkout Code") {
            steps {
                git branch: "master",
                    url: "https://github.com/Vinivinay52/hello-world-war.git"
            }
        }

        // Find the actual chart dir even if the repo has spaces / special hyphens in parent folder names
        stage("Locate chart dir") {
            steps {
                script {
                    def found = sh(
                        returnStdout: true,
                        label: "find chart dir",
                        script: '''
                            set -e
                            p=$(find . -type f -path "*/helm/hello-world-war/values.yaml" -print -quit)
                            if [ -n "$p" ]; then
                              dirname "$(dirname "$p")"   # -> .../helm/hello-world-war
                            fi
                        '''
                    ).trim()

                    if (!found) {
                        error "Could not locate values.yaml for hello-world-war chart (pattern */helm/hello-world-war/values.yaml)"
                    }

                    env.CHART_DIR_RESOLVED = found.replaceFirst(/^\\.\//, "")
                    echo "Resolved chart dir: ${env.CHART_DIR_RESOLVED}"
                }
            }
        }

        stage("Verify Tools") {
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

        stage("Build WAR") {
            steps {
                sh '''
                    set -e
                    mvn clean package -DskipTests
                '''
            }
        }

        stage("Build Docker Image") {
            steps {
                sh """
                    set -e
                    docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
                    docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest
                """
            }
        }

        stage("Push Docker Image") {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "docker-creds",
                    usernameVariable: "DOCKER_USER",
                    passwordVariable: "DOCKER_PASS"
                )]) {
                    sh '''
                        set -e
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push "$DOCKER_IMAGE:$IMAGE_TAG"
                        docker push "$DOCKER_IMAGE:latest"
                        docker logout || true
                    '''
                }
            }
        }

        stage("Update values.yaml") {
            steps {
                withEnv([
                    "CHART_DIR_RESOLVED=${CHART_DIR_RESOLVED}",
                    "DOCKER_IMAGE=${DOCKER_IMAGE}",
                    "IMAGE_TAG=${IMAGE_TAG}",
                    "WORKSPACE_DIR=${WORKSPACE}"
                ]) {
                    sh '''
                        set -e
                        echo "===== Workspace ====="
                        pwd
                        ls -la
                        echo "Resolved chart dir: ${CHART_DIR_RESOLVED}"
                        [ -f "${CHART_DIR_RESOLVED}/values.yaml" ] || { echo "values.yaml not found at ${CHART_DIR_RESOLVED}"; exit 2; }

                        python3 - <<'PY'
from pathlib import Path
import os, re

chart_dir = os.environ["CHART_DIR_RESOLVED"]
repo      = os.environ["DOCKER_IMAGE"]
tag       = os.environ.get("IMAGE_TAG") or os.environ.get("BUILD_NUMBER","latest")

p = Path(chart_dir) / "values.yaml"
print("Using file:", p)
if not p.exists():
    raise FileNotFoundError("values.yaml not found at: %s" % p)

text = p.read_text()

def upsert(pattern, replacement, text):
    if re.search(pattern, text, flags=re.M):
        return re.sub(pattern, replacement, text, flags=re.M)
    if "image:" in text:
        return re.sub(r"(^image:\\s*$)",
                      "\\1\\n  repository: " + repo + "\\n  tag: \\"" + tag + "\\"\\n  pullPolicy: Always",
                      text, flags=re.M)
    return text + "\\nimage:\\n  repository: " + repo + "\\n  tag: \\"" + tag + "\\"\\n  pullPolicy: Always\\n"

text = upsert(r"^\\s*repository:\\s*.*$", "  repository: " + repo, text)
text = upsert(r"^\\s*tag:\\s*.*$",        "  tag: \\"" + tag + "\\"", text)
text = upsert(r"^\\s*pullPolicy:\\s*.*$", "  pullPolicy: Always", text)

p.write_text(text)
print("values.yaml updated successfully")
PY

                        echo "===== Updated values.yaml ====="
                        sed -n '1,120p' "${CHART_DIR_RESOLVED}/values.yaml"
                    '''
                }
            }
        }

        stage("Update Chart.yaml version") {
            steps {
                sh '''
                    set -e
                    sed -i "s|^version:.*|version: 0.1.'"$BUILD_NUMBER"'|" "${CHART_DIR_RESOLVED}/Chart.yaml"
                    sed -i "s|^appVersion:.*|appVersion: \\"'"$IMAGE_TAG"'\\"|" "${CHART_DIR_RESOLVED}/Chart.yaml"
                    echo "===== Updated Chart.yaml ====="
                    cat "${CHART_DIR_RESOLVED}/Chart.yaml"
                '''
            }
        }

        stage("Lint Chart") {
            steps {
                sh 'helm lint "${CHART_DIR_RESOLVED}"'
            }
        }

        stage("Package Chart") {
            steps {
                sh '''
                    set -e
                    mkdir -p packaged
                    rm -f packaged/*.tgz
                    helm package "${CHART_DIR_RESOLVED}" -d packaged
                    echo "===== Packaged Chart ====="
                    ls -lh packaged
                '''
            }
        }

        stage("Login to JFrog (Helm OCI)") {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "jfrog-creds",
                    usernameVariable: "JFROG_USER",
                    passwordVariable: "JFROG_PASS"
                )]) {
                    sh '''
                        set -e
                        echo "$JFROG_PASS" | helm registry login '"$JFROG_HOST"' -u "$JFROG_USER" --password-stdin
                    '''
                }
            }
        }

        stage("Push Chart to JFrog OCI") {
            steps {
                sh '''
                    set -e
                    CHART_PKG=$(ls packaged/*.tgz | head -n 1)
                    if [ -z "$CHART_PKG" ]; then echo "ERROR: No chart package found in packaged/"; exit 2; fi
                    echo "Pushing: $CHART_PKG -> '"$JFROG_OCI_URL"'"
                    helm push "$CHART_PKG" '"$JFROG_OCI_URL"'
                '''
            }
        }

        stage("Deploy to Kubernetes") {
            steps {
                sh '''
                    set -e
                    export KUBECONFIG='"$KUBECONFIG"'
                    CHART_VERSION=$(grep '^version:' "${CHART_DIR_RESOLVED}/Chart.yaml" | awk '{print $2}')

                    echo "===== Deploy ====="
                    echo "Chart: '"$CHART_NAME"'  Version: $CHART_VERSION"
                    echo "Image: '"$DOCKER_IMAGE:$IMAGE_TAG"'"

                    helm upgrade --install '"$RELEASE_NAME"' '"$JFROG_OCI_URL"'/'"$CHART_NAME"' \
                      --version "$CHART_VERSION" \
                      --namespace '"$KUBE_NAMESPACE"' \
                      --create-namespace \
                      --set image.repository='"$DOCKER_IMAGE"' \
                      --set image.tag='"$IMAGE_TAG"' \
                      --set image.pullPolicy=Always \
                      --wait --atomic --debug

                    echo "===== Pods ====="
                    kubectl get pods -n '"$KUBE_NAMESPACE"'
                    echo "===== Services ====="
                    kubectl get svc -n '"$KUBE_NAMESPACE"'
                '''
            }
        }
    }

    post {
        always {
            sh "helm registry logout ${JFROG_HOST} || true"
            cleanWs()
        }
        success {
            echo "SUCCESS: Image built & pushed; chart pushed to Artifactory; deployed to cluster."
        }
        failure {
            echo "FAILED: Check stage logs above."
        }
    }
}
