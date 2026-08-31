# devops-cicd-demo

A small Spring Boot web app used as the subject of an end-to-end DevOps / CI-CD workshop:
build → test → static analysis → container scan → registry push → deploy to a local
Kubernetes cluster → observe with Prometheus/Grafana.

## App

A single-page feedback form (name + message) backed by an in-memory store. Built with:

- Java 21, Spring Boot 4.1.1, Maven
- Spring MVC + Thymeleaf for the UI
- Spring Boot Actuator + Micrometer, exposing a custom Prometheus counter
  (`app_submissions_total`) and gauge (`app_submissions_current`)
- JUnit 5 / MockMvc / Mockito tests

## Run locally

```bash
./mvnw spring-boot:run
```

Then open http://localhost:8080.

## Run tests

```bash
./mvnw clean verify
```

## Build & run the container

```bash
docker build -t devops-demo:local .
docker run -p 8080:8080 devops-demo:local
```

## Pipeline

This repo is being built up stage by stage as part of a CI/CD workshop:

- [x] Spring Boot app + tests
- [x] Actuator + Micrometer + custom Prometheus metrics
- [x] Dockerfile
- [x] GitHub Actions CI (build, test, SonarCloud, Trivy, push to GHCR)
- [x] Helm chart
- [x] Deploy to a local `kind` cluster
- [x] Prometheus + Grafana + Alertmanager + Loki observability stack -- see
      [observability/README.md](observability/README.md)
