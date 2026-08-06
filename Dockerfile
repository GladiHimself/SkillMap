# ── Stage 1: Build ────────────────────────────────────────────
# Uses Maven + Java 21 to compile the app
# This stage is discarded after building — never in final image
FROM maven:3.9.6-amazoncorretto-21 AS builder

# Set working directory inside the container
WORKDIR /app

# Copy pom.xml first — Docker caches this layer
# If pom.xml hasn't changed, Maven dependencies aren't re-downloaded
COPY pom.xml .

# Download all dependencies (cached unless pom.xml changes)
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the jar — skip tests (tests run in CI, not here)
RUN mvn clean package -DskipTests -B

# ── Stage 2: Run ──────────────────────────────────────────────
# Only Java runtime — no Maven, no source code, no build tools
# Much smaller final image
FROM amazoncorretto:21-al2023-jdk

# Working directory
WORKDIR /app

# Copy ONLY the jar from the builder stage
# Everything else from Stage 1 is discarded
COPY --from=builder /app/target/*.jar app.jar

# Which port the app listens on (documentation only — doesn't open port)
EXPOSE 8080

# Health check — ECS uses this to know if container is healthy
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -q -O- http://localhost:8080/actuator/health || exit 1

# Command to run when container starts
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]