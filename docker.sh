
#!/usr/bin/env bash
set -euo pipefail

# ---------- Configurable variables ----------
IMAGE_NAME="demo-app"
IMAGE_TAG="centos9"
ARTIFACT="demo-0.0.1-SNAPSHOT.jar"   # Change if your built JAR has a different name
PORT="8080"                          # Change if your app listens on a different port
# -------------------------------------------

echo "==> Writing Dockerfile (clean, correct syntax)..."
cat > Dockerfile <<'EOF'
# =========================
# BUILD STAGE (CentOS Stream 9 + JDK 21 + Maven)
# =========================
FROM quay.io/centos/centos:stream9 AS build

# Install JDK 21 and Maven
RUN dnf -y install java-21-openjdk-devel maven tar gzip shadow-utils \
    && dnf clean all

# Ensure Maven uses JDK 21
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

WORKDIR /workspace

# Optional sanity check
RUN java -version && javac -version && mvn -version

# Copy project and build (skip tests for speed)
COPY . .
RUN mvn -B -DskipTests clean package

# =========================
# RUNTIME STAGE (CentOS Stream 9 + JRE 21)
# =========================
FROM quay.io/centos/centos:stream9 AS runtime

# Install headless JRE 21 for runtime
RUN dnf -y install java-21-openjdk-headless shadow-utils \
    && dnf clean all

# Ensure runtime uses JRE 21
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Create non-root user
RUN useradd -m -U -r -s /sbin/nologin appuser

WORKDIR /app

# Copy the built JAR from the build stage (update name if needed)
# NOTE: The build stage produces target/<artifact>.jar; we rename it to app.jar here.
COPY --from=build /workspace/target/REPLACE_ARTIFACT /app/app.jar

EXPOSE 8080
USER appuser

# ✅ Exec-form ENTRYPOINT (no shell, no quoting issues)
ENTRYPOINT ["java","-jar","/app/app.jar"]
EOF

# Replace placeholder artifact name in Dockerfile
sed -i "s|REPLACE_ARTIFACT|${ARTIFACT}|g" Dockerfile

echo "==> Checking that the artifact exists in your local 'target/' folder..."
if [[ ! -f "target/${ARTIFACT}" ]]; then
  echo "!! The file 'target/${ARTIFACT}' was not found."
  echo "-> Running 'mvn -B -DskipTests clean package' locally to produce it..."
  mvn -B -DskipTests clean package || {
    echo "Build failed locally. Ensure Maven/Java installed or let Docker build handle it."
  }
fi

echo "==> Building image ${IMAGE_NAME}:${IMAGE_TAG} without cache..."
docker build --no-cache -t "${IMAGE_NAME}:${IMAGE_TAG}" .

echo "==> Inspecting image entrypoint..."
docker inspect "${IMAGE_NAME}:${IMAGE_TAG}" --format '{{json .Config.Entrypoint}} {{json .Config.Cmd}}'

echo "==> Listing /app inside the image to confirm app.jar is present..."
docker run --rm --entrypoint ls "${IMAGE_NAME}:${IMAGE_TAG}" -l /app

echo "==> Running the container (port ${PORT})..."
CONTAINER_NAME="${IMAGE_NAME//[:]/-}-run"
# Stop and remove any previous container with same name
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

# Start container in the foreground (remove --rm to keep it for logs inspection)
docker run --name "${CONTAINER_NAME}" -p "${PORT}:${PORT}" "${IMAGE_NAME}:${IMAGE_TAG}" &

# Give it a few seconds to start
sleep 3

echo "==> Checking container status..."
docker ps --filter "name=${CONTAINER_NAME}"

echo "==> Tail logs (5s)..."
timeout 5s docker logs -f "${CONTAINER_NAME}" || true

echo "==> Curl the app (http://localhost:${PORT})..."
# This may fail if your app's root path is different; adjust if needed.
if command -v curl >/dev/null 2>&1; then
  curl -s -S "http://localhost:${PORT}" || echo "-> Curl failed (maybe app uses different path or needs time)."
else
  echo "curl not found on host; skipping HTTP check."
fi

echo "==> Done. To keep the container running, remove the '&' and run in foreground."
echo "    To check logs:   docker logs -f ${CONTAINER_NAME}"
echo "   

