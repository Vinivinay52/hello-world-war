pipeline {
    agent any

    environment {
        APP_NAME        = "hello-world-war"

        // Docker image
        DOCKER_IMAGE    = "thorvini/hello-world-war"
        IMAGE_TAG       = "${BUILD_NUMBER}"

        // Nominal chart location (we will auto-resolve the actual path at runtime)
        CHART_DIR       = "helm/hello-world-war"
        CHART_NAME      = "hello-world-war"

        // JFrog Helm (OCI)
        JFROG_HOST      = "trialf5h0jz.jfrog.io"
        JFROG_HELM_REPO = "hello-world-war"
        JFROG_OCI_URL   = "oci://${JFROG_HOST}/${JFROG_HELM_REPO}"

        // Kubernetes
        KUBE_NAMESPACE  = "default"
        RELEASE_NAME    = "hello-world-war"
        KUBECONFIG      = "/var/lib/jenkins/.kube/config"

        // Free NodePort (your scan showed 30080 and 31174 are in use)
        NODE_PORT       = "30081"
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

        // Resolve the chart directory that directly contains values.yaml (handles spaces/special chars)
        stage("Locate chart dir") {
            steps {
                script {
                    def found = sh(
                        returnStdout: true,
                        label: "find chart dir",
                        script: '''
                            set -e
                            # Find .../helm/hello-world-war/values.yaml anywhere in the repo
                            p=$(find . -type f -path "*/helm/hello-world-war/values.yaml" -print -quit)
                            if [ -n "$p" ]; then
                              # Return the directory that directly contains values.yaml (helm/hello-world-war)
                              dirname "$p"
                            fi
                        '''
                    ).trim()

                    if (!found) {
                        error "Could not locate values.yaml for hello-world-war chart (pattern */helm/hello-world-war/values.yaml)"
                    }

                    // Normalize leading "./" if present
                    env.CHART_DIR_RESOLVED = found.replaceFirst(/^\\.\//, "")
                    echo "Resolved chart dir: ${env.CHART_DIR_RESOLVED}"
                }
            }
        }

        stage("Verify Tools") {
            steps {
                sh '''
                    set -e
                    echo "===== Workspace ====="
                    pwd
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

        // SAFE Python updater (no Groovy interpolation; reads env via os.environ)
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
                        echo "Resolved chart dir: ${CHART_DIR_RESOLVED}"
                        [ -f "${CHART_DIR_RESOLVED}/values.yaml" ] || { echo "values.yaml not found at ${CHART_DIR_RESOLVED}"; exit 2; }

                        # Single-quoted heredoc so no Groovy/shell interpolation inside Python
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

        // Write clean SemVer (no stray quotes)
        stage("Update Chart.yaml version") {
            steps {
                sh """
                    set -e
                    sed -i 's|^version:.*|version: 0.1.${BUILD_NUMBER}|' "${CHART_DIR_RESOLVED}/Chart.yaml"
                    sed -i 's|^appVersion:.*|appVersion: "${IMAGE_TAG}"|' "${CHART_DIR_RESOLVED}/Chart.yaml"

                    echo "===== Updated Chart.yaml ====="
                    cat "${CHART_DIR_RESOLVED}/Chart.yaml"
                """
            }
        }

        stage("Lint Chart") {
            steps {
                sh "helm lint \"${CHART_DIR_RESOLVED}\""
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
                        echo "$JFROG_PASS" | helm registry login "$JFROG_HOST" -u "$JFROG_USER" --password-stdin
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
                    echo "Pushing: $CHART_PKG -> $JFROG_OCI_URL"
                    helm push "$CHART_PKG" "$JFROG_OCI_URL"
                '''
            }
        }

        stage("Deploy to Kubernetes") {
            steps {
                sh """
                    set -e
                    export KUBECONFIG=${KUBECONFIG}

                    CHART_VERSION=\$(grep '^version:' "${CHART_DIR_RESOLVED}/Chart.yaml" | awk '{print \$2}')

                    echo "===== Deploy ====="
                    echo "Chart: ${CHART_NAME}  Version: \$CHART_VERSION"
                    echo "Image: ${DOCKER_IMAGE}:${IMAGE_TAG}"

                    helm upgrade --install ${RELEASE_NAME} ${JFROG_OCI_URL}/${CHART_NAME} \\
                      --version \$CHART_VERSION \\
                      --namespace ${KUBE_NAMESPACE} \\
                      --create-namespace \\
                      --set image.repository=${DOCKER_IMAGE} \\
                      --set image.tag=${IMAGE_TAG} \\
                      --set image.pullPolicy=Always \\
                      --set service.type=NodePort \\
                      --set service.nodePort=${NODE_PORT} \\
                      --wait --atomic --debug

                    echo "===== Pods ====="
                    kubectl get pods -n ${KUBE_NAMESPACE}
                    echo "===== Services ====="
                    kubectl get svc -n ${KUBE_NAMESPACE}
                    echo "Open: http://<any-node-ip>:${NODE_PORT}/"
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
            echo "SUCCESS: Image built & pushed; chart pushed to Artifactory; deployed to cluster."
        }
        failure {
            echo "FAILED: Check stage logs above."
        }
    }
}
