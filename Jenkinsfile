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
