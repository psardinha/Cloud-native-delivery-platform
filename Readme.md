# Cloud-Native Delivery Platform

A cloud-native CI/CD platform for building, securing, packaging, publishing and deploying applications to Kubernetes using **GitHub Actions, Docker, Helm and Kubernetes**.

The platform provides a repeatable path from application source code to a verified Kubernetes deployment, with environment-specific configuration kept outside the container image.

## About

The workload is the backend of the [Full Stack Observability](https://github.com/psardinha/full-stack-observability) application.

The frontend is intentionally outside the scope of this exercise. The backend is a **Quarkus** application exposing the String Reversal Service used by the deployment smoke test.

The application is used as a realistic workload, but the delivery platform itself is **application-agnostic**.

## Architecture

```text
┌─────────────────────────────────┐
│ Full Stack Observability repo   │
│                                 │
│ ┌─────────────┐ ┌─────────────┐ │
│ │  Frontend   │ │   Backend   │ │
│ │   (unused)  │ │  Quarkus    │ │
│ └─────────────┘ └──────┬──────┘ │
└────────────────────────┼────────┘
                         │
                         │ checkout backend
                         ▼
              ┌───────────────────────┐
              │  GitHub Actions CI/CD │
              │                       │
              │  Build                │
              │  Test                 │
              │  Secret scanning      │
              │  SonarCloud analysis  │──────────→ SonarCloud
              │  Quality gate         │              
              │  Dependency scan      │
              │  Container scan       │
              │  Docker build/push    │
              │  Helm validation      │
              │  Kubernetes deploy    │
              │  Smoke tests          │
              └───────────┬───────────┘
                          │
                          ▼
               ┌────────────────────┐
               │ Container Registry │
               │ Container          │
               │ Image              │
               └──────────┬─────────┘
                          │
                          ▼
                  ┌───────────────┐
                  │ Kubernetes    │
                  │     kind      │
                  │               │
                  │ Helm release  │
                  │ Quarkus pod   │
                  └───────┬───────┘
                          │
                          ▼
                  ┌───────────────┐
                  │ Smoke tests   │
                  │               │
                  │ readiness     │
                  │ /utils/reverse│
                  └───────────────┘
```

The architecture deliberately separates the **application repository** from the **delivery-platform repository**.

## Delivery pipeline

The workflow is defined in:

```text
.github/workflows/cicd.yml
```

The workflow can be started manually with:

```yaml
on:
  workflow_dispatch:
```

It can also be triggered by changes to the backend of the [Full Stack Observability](https://github.com/psardinha/full-stack-observability) application repository.

The pipeline follows:

**Checkout → Build → Test → Code Quality → Secure → Package → Publish → Deploy → Verify**

SonarCloud analysis is performed against the backend source code and uploaded to SonarCloud. The workflow waits for the SonarCloud Quality Gate and fails the pipeline if the configured quality criteria are not met.

Security reports are uploaded as CI artifacts, the image is tagged with the Git commit SHA and the deployed application is verified through Kubernetes readiness checks and a functional smoke test.


## Implemented

The platform currently provides:

- GitHub Actions CI/CD
- Independent application repository checkout
- Java 25 / Eclipse Temurin
- Maven build, caching, unit tests and integration tests
- JaCoCo code coverage reporting
- JaCoCo enforcement of a minimum 80% overall line coverage
- SonarCloud static code analysis
- SonarCloud analysis of JaCoCo test coverage
- SonarCloud Quality Gate enforcement
- Gitleaks secret scanning
- OWASP Dependency-Check dependency scanning
- Trivy container scanning
- HTML vulnerability reports as CI artifacts
- Downloadable SonarCloud analysis report as a CI artifact
- Docker image build and publication
- Git SHA image tagging
- Helm lint and template validation
- Kubernetes deployment using kind
- Kubernetes liveness, readiness and startup probes
- Runtime configuration through Helm values and environment variables
- Application readiness verification
- Functional deployment smoke testing

## Security

Dependency and container vulnerability scans currently provide detection and reporting rather than enforcement.

The scanning steps use:

```yaml
continue-on-error: true
```

This is intentional for the exercise. A production implementation would define a vulnerability policy covering severity thresholds, exceptions, remediation requirements and conditions that block delivery.

Secret scanning is performed with **Gitleaks**.

## Code Quality

Static code analysis is performed using SonarCloud.

### JaCoCo

The backend uses JaCoCo to generate a code coverage report during the Maven test lifecycle.

The Maven build enforces a minimum overall **80% line coverage**:

```xml
<counter>LINE</counter>
<value>COVEREDRATIO</value>
<minimum>0.80</minimum>
```

If overall line coverage falls below 80%, the Maven verify phase fails and the CI pipeline stops.

The coverage report is also generated in JaCoCo XML format and is consumed by SonarCloud during static analysis.

### SonarCloud

The backend is analyzed during the CI pipeline using the Sonar Maven Scanner. The analysis is uploaded to SonarCloud and the workflow waits for the configured Quality Gate:

```yaml
-Dsonar.qualitygate.wait=true
```

The SonarCloud Quality Gate provides an additional quality check on the analyzed code, including the coverage metrics reported by JaCoCo.

A failed Quality Gate causes the CI workflow to fail, preventing subsequent delivery stages from executing.

The resulting SonarCloud analysis report is also exported as a downloadable CI artifact.


## Container image

The backend is packaged as a Docker image and tagged with the Git commit SHA:

```yaml
full-stack-observability:${{ github.sha }}
```

This provides traceability between:

```text
Git commit
     │
     ▼
Docker image
     │
     ▼
Kubernetes deployment
```

The image is published to the configured container registry using **GitHub Variables and Secrets**.

## Runtime configuration with Helm

Environment-specific configuration is kept outside the container image.

Examples include:

```text
OTEL_EXPORTER_OTLP_ENDPOINT
OTEL_PROXY_COLLECTOR_URL
CORS_ORIGINS
```

The configuration flow is:

```text
                    application.properties
                               │
                               │ reads environment variables
                               ▼
                ┌─────────────────────────────┐
                │ OTEL_EXPORTER_OTLP_ENDPOINT │
                │ OTEL_PROXY_COLLECTOR_URL    │
                │ CORS_ORIGINS                │
                └──────────────┬──────────────┘
                               │
                               ▼
                        Helm values.yaml
                               │
                               ▼
                      Kubernetes Deployment
                               │
                               ▼
                      Container environment
                               │
                               ▼ 
                       Quarkus application
```

This allows the same container image to be deployed with different environment-specific configuration.

Credentials remain in **GitHub Secrets**, while non-sensitive configuration is supplied through **GitHub Variables and Helm values**.

## Kubernetes deployment

The workflow creates a temporary kind cluster and deploys the application using Helm.

The chart is validated with:

```text
helm lint
helm template
```

Deployment uses:

```text
helm upgrade --install
```

The application exposes:

```text
/q/health/live
/q/health/ready
/q/health/started
```

which are used for Kubernetes liveness, readiness and startup probes.

After deployment, the workflow verifies readiness and performs a functional smoke test:

```text
POST /utils/reverse
```

with:

```text
{"input":"string"}
```

Expected response:

```text
gnirts
```

## Out of Scope

### CVE remediation and enforcement

Vulnerability remediation and enforcement policies are outside the scope of this exercise. Scans currently provide detection and reporting only.

### LGTM deployment

Deployment and configuration of **Loki, Grafana, Tempo and Mimir (LGTM)** are outside the scope.

The application contains OpenTelemetry-related configuration, but this project does not provision an LGTM environment or validate end-to-end observability data flow.

## Repository structure

```text
.
├── .github/
│   └── workflows/
│       └── cicd.yml
│
├── helm/
│   └── full-stack-observability/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│
└── README.md
```

The application source remains in its separate repository.


## Running the workflow

Start the workflow from **GitHub Actions** using workflow_dispatch.

The repository must contain the required GitHub Variables and Secrets for the configured container registry.

No pre-existing Kubernetes cluster is required; the workflow creates its own kind cluster.

## Design Principles

- **Immutable artifacts** — images are tagged with the Git commit SHA.
- **Configuration outside the image** — environment-specific values are supplied at deployment time.
- **Secrets outside source control** — credentials are stored in GitHub Secrets.
- **Security integrated into CI/CD** — secret and vulnerability scanning are part of the pipeline.
- **Application/platform separation** — the workload and delivery platform are maintained independently.
- **Post-deployment verification** — deployment success requires both readiness and functional validation.

## Future Improvements

Possible extensions include:

- automatic triggers from application changes
- enforceable vulnerability policies
- vulnerability exception management
- SonarCloud quality-profile customization
- persistent Kubernetes environments
- automated rollback and progressive delivery
- release promotion between environments
- OpenTelemetry Collector deployment
- delivery-platform observability
- stronger Kubernetes security controls
