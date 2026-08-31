# --- Build stage ---
FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace

COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
RUN ./mvnw -q dependency:go-offline

COPY src src
RUN ./mvnw -q clean package -DskipTests

# --- Runtime stage ---
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN apk upgrade --no-cache && \
    addgroup -g 1001 spring && adduser -D -u 1001 -G spring spring
COPY --from=build /workspace/target/devops-demo-*.jar app.jar
RUN chown spring:spring app.jar
USER 1001

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health/liveness | grep -q '"status":"UP"' || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
