
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="demo-app"
TAG="21"

echo "==> Writing a clean pom.xml (Spring Boot 3.2.5, Java 21, with Web)..."
cat > pom.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">

  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.5</version>
    <relativePath/>
  </parent>

  <groupId>com.example</groupId>
  <artifactId>demo</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <name>demo</name>
  <description>Demo project for Spring Boot</description>
  <packaging>jar</packaging>

  <properties>
    <java.version>21</java.version>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter</artifactId>
    </dependency>

    <!-- Needed for @RestController/@GetMapping -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>

    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
        <configuration>
          <layers>
            <enabled>true</enabled>
          </layers>
        </configuration>
      </plugin>

      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.11.0</version>
        <configuration>
          <release>21</release>
        </configuration>
      </plugin>

      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>3.2.5</version>
      </plugin>
    </plugins>
  </build>

</project>
XML

echo "==> Verifying pom.xml..."
if grep -nE '&lt;|&gt;' pom.xml >/dev/null 2>&1; then
  echo "ERROR: pom.xml contains HTML-escaped tags (&lt; or &gt;)."
  exit 1
fi
if ! tail -n 1 pom.xml | grep -q '</project>'; then
  echo "ERROR: pom.xml does not end with </project>."
  exit 1
fi

echo "==> Writing Dockerfile (build with Maven in container, then run on JRE 21)..."
cat > Dockerfile <<'DOCKER'
# =========================
# BUILD STAGE (JDK 21 + Maven)
# =========================
FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace

RUN apt-get update \
    && apt-get install -y --no-install-recommends maven \
    && rm -rf /var/lib/apt/lists/*

# Copy all project files
COPY . .

# Show POM in the build context (debug)
RUN echo "---- POM inside container (first 200 lines) ----" && sed -n '1,200p' pom.xml && echo "---- END POM ----"

# Build (skip tests for speed; remove -DskipTests if you want tests)
RUN mvn -B -DskipTests clean package

# =========================
# RUNTIME STAGE (JRE 21)
# =========================
FROM eclipse-temurin:21-jre
RUN adduser --disabled-password --gecos "" appuser
WORKDIR /app

# Copy the fat jar from build stage
COPY --from=build /workspace/target/demo-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8080
USER appuser
ENTRYPOINT ["java","-jar","/app/app.jar"]
DOCKER

echo "==> Writing .dockerignore..."
cat > .dockerignore <<'IGN'
target/
.git/
IGN

echo "==> Building Docker image ${APP_NAME}:${TAG} ..."
docker build -t "${APP_NAME}:${TAG}" .

echo "==> Build complete."
echo "Run the container:"
echo "  docker run --rmecho "  docker run --rm -p 8080:8080 ${APP_NAME}:${TAG}"
echo "Test endpoints:"
echo "  curl http://localhost:8080/"
