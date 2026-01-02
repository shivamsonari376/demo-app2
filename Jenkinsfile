
pipeline {
    agent any

    environment {
        // Jenkins credentials bindings
        OPENSHIFT_TOKEN = credentials('openshift-token')
        DOCKERHUB       = credentials('dockerhub-registry') // provides DOCKERHUB_USR and DOCKERHUB_PSW

        // Fixed values based on your environment
        OPENSHIFT_API     = 'https://api.rm3.7wse.p1.openshiftapps.com:6443'
        OPENSHIFT_PROJECT = 'shivam-j-singh-dev'
        GIT_URL           = 'https://github.com/shivamsonari376/demo-app2.git'
        GIT_BRANCH        = 'main'

        // Image repo stays fixed; tag will be the commit SHA
        DOCKER_IMAGE     = 'docker.io/ankitsonari376/demo-app2'
        HELM_RELEASE     = 'demo-app2'
        HELM_CHART_PATH  = './demo-app2'
    }

    options {
        timestamps()
        // ansiColor('xterm') // enable if plugin installed
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    // Trigger on GitHub webhook push events
    triggers {
        githubPush()
        // pollSCM('H/5 * * * *') // optional fallback if webhook isn’t reachable
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
                // Public repo: credentials not required
                git branch: "${GIT_BRANCH}",
                    url: "${GIT_URL}"
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                set -e
                # Use the commit SHA as the image tag (available after checkout)
                TAG="${GIT_COMMIT}"
                echo "==> Building image ${DOCKER_IMAGE}:${TAG}"
                docker build -t ${DOCKER_IMAGE}:${TAG} .
                docker images | grep -E "REPOSITORY|${DOCKER_IMAGE}" || true
                '''
            }
        }

        stage('Push Docker Image') {
            steps {
                sh '''
                set -e
                TAG="${GIT_COMMIT}"

                echo "==> Logging in to Docker Hub as $DOCKERHUB_USR"
                echo "$DOCKERHUB_PSW" | docker login -u "$DOCKERHUB_USR" --password-stdin

                echo "==> Pushing ${DOCKER_IMAGE}:${TAG}"
                docker push ${DOCKER_IMAGE}:${TAG}
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

                echo "==> Existing deployments:"
                oc get deploy -n "${OPENSHIFT_PROJECT}" || true

                echo "==> Existing pods:"
                oc get pods -n "${OPENSHIFT_PROJECT}" -o wide || true
                '''
            }
        }

        stage('Helm Deploy to OpenShift') {
            steps {
                sh '''
                set -e
                TAG="${GIT_COMMIT}"

                echo "==> Helm upgrade/install: release=${HELM_RELEASE}, chart=${HELM_CHART_PATH}, tag=${TAG}"
                helm upgrade --install "${HELM_RELEASE}" "${HELM_CHART_PATH}" \
                  --set image.repository="${DOCKER_IMAGE}" \
                  --set image.tag="${TAG}" \
                  --set image.pullPolicy=Always \
                  --namespace "${OPENSHIFT_PROJECT}" \
                  --reuse-values

                echo "==> Waiting for rollout..."
                # NOTE: If your chart names the Deployment differently, adjust this name:
                # e.g., oc rollout status deployment/demo-app2-deployment ...
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
            echo "Pipeline failed. Please review the stage logs."
        }
        always {
            sh '''
            docker logout || true
            '''
        }
    }
}

