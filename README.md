# devops-cicd-demo

A small Spring Boot web app used as the subject of an end-to-end DevOps / CI-CD workshop:
build → test → static analysis → container scan → registry push → deploy to a local
Kubernetes cluster → observe with Prometheus/Grafana.

## Quick start

Bring up the whole thing -- build, containerize, local `kind` cluster, app, and the full
Prometheus/Grafana/Loki/Alertmanager stack -- with one command:

```bash
./scripts/run-pipeline.sh
```

Requires Docker Desktop running plus `kind`, `kubectl`, and `helm` on your PATH; the script
checks for all of them and tells you what's missing. It's idempotent, so re-run it any time
you change code, a chart, or a values file. `./scripts/run-pipeline.sh --help` covers the
`--no-tests`, `--down`, and `--destroy` flags.

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
- [x] Branch protection on `main`
- [x] One-command local bootstrap -- [scripts/run-pipeline.sh](scripts/run-pipeline.sh)

## Contributing

`main` is protected: changes go through a pull request, and `build-test-analyze`,
`docker-build-scan-push`, and `SonarCloud Code Analysis` must all pass before merging.

```bash
git checkout -b my-change
# ...make changes...
git push -u origin my-change
gh pr create
```
