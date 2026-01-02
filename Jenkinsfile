pipeline {
    agent any

    environment {
        // Jenkins credentials bindings
        OPENSHIFT_TOKEN = credentials('openshift-token')
        DOCKERHUB = credentials('dockerhub-registry') // exposes DOCKERHUB_USR and DOCKERHUB_PSW

        // Fixed values based on your environment
        OPENSHIFT_API = 'https://api.rm3.7wse.p1.openshiftapps.com:6443'
        OPENSHIFT_PROJECT = 'shivam-j-singh-dev'
        GIT_URL = 'https://github.com/shivamsonari376/demo-app2.git'
        GIT_BRANCH = 'main'
        DOCKER_IMAGE = 'docker.io/ankitsonari376/demo-app2'
        IMAGE_TAG = 'latest'
        HELM_RELEASE = 'demo-app2'
        HELM_CHART_PATH = './demo-app2'
    }

    options {
        timestamps()
        // If you later install the AnsiColor plugin, you can re-enable:
        // ansiColor('xterm')
    }

    // Trigger on GitHub webhook push events
    triggers {
        githubPush()
        // Optional fallback if webhook isn’t reachable:
        // pollSCM('H/5 * * * *')
    }

    stages {
        stage('Pre-flight checks') {
            steps {
                sh '''
                set -e
                echo "==> Checking required CLIs..."
                which docker || (echo "docker not found"; exit 1)
                which oc     || (echo "oc not found"; exit 1)
                which helm   || (echo "helm not found"; exit 1)
                docker version || true
                oc version || true
                helm version || true
                '''
            }
        }

        stage('Checkout') {
            steps {
                git branch: "${GIT_BRANCH}",
                    url: "${GIT_URL}",
                    credentialsId: 'github-token'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                set -e
                echo "==> Building image ${DOCKER_IMAGE}:${IMAGE_TAG}"
                docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
                docker images | grep -E "REPOSITORY|${DOCKER_IMAGE}" || true
                '''
            }
        }

        stage('Push Docker Image') {
            steps {
                sh '''
                set -e
                echo "==> Logging in to Docker Hub as $DOCKERHUB_USR"
                echo "$DOCKERHUB_PSW" | docker login -u "$DOCKERHUB_USR" --password-stdin
                echo "==> Pushing ${DOCKER_IMAGE}:${IMAGE_TAG}"
                docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                '''
            }
        }

        stage('OpenShift Login & Project') {
            steps {
                sh '''
                set -e
                echo "==> Logging into OpenShift API ${OPENSHIFT_API}"
                oc login --token="$OPENSHIFT_TOKEN" --server="${OPENSHIFT_API}" --insecure-skip-tls-verify=true
                echo "==> Switching to project ${OPENSHIFT_PROJECT}"
                oc project "${OPENSHIFT_PROJECT}"
                echo "==> Current user:"
                oc whoami
                echo "==> Existing pods:"
                oc get pods -n "${OPENSHIFT_PROJECT}" -o wide || true
                '''
            }
        }

        stage('Helm Deploy to OpenShift') {
            steps {
                sh '''
                set -e
                echo "==> Helm upgrade/install: release=${HELM_RELEASE}, chart=${HELM_CHART_PATH}"
                helm upgrade --install "${HELM_RELEASE}" "${HELM_CHART_PATH}" \
                  --set image.repository="${DOCKER_IMAGE}" \
                  --set image.tag="${IMAGE_TAG}" \
                  --namespace "${OPENSHIFT_PROJECT}"

                echo "==> Waiting for rollout..."
                # Adjust deployment name if your chart uses another name
                # e.g., demo-app2-deployment
                oc rollout status deployment/${HELM_RELEASE} --namespace "${OPENSHIFT_PROJECT}" --timeout=180s || true

                echo "==> Pods after deploy:"
                oc get pods -n "${OPENSHIFT_PROJECT}" -o wide
                '''
            }
        }
    }

    post {
        success {
            echo "Deployment successful: ${HELM_RELEASE} in project ${OPENSHIFT_PROJECT}"
        }
        failure {
            echo " Pipeline failed. Please review the stage logs."
        }
        always {
            sh '''
            docker logout || true
            '''
        }
    }
}

