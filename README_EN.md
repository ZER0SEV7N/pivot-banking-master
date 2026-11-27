# Pivot Banking System - Environment, Orchestration & Infrastructure (`pivot-banking-master`)

> **Versión en español:** [README.md](README.md)

## Overview
Master infrastructure, operational configuration, observability, architecture diagrams, and container orchestration repository for the **Pivot Banking System** (Phases I, II, and III). It centralizes the startup, verification, and lifecycle management of the full reactive microservices ecosystem (Java 17, Spring Boot 4.1.2, Spring WebFlux, RxJava 3) on **Kubernetes (Docker Desktop)** as well as local development via **Docker Compose** and **HashiCorp Vault**.

## Deployed Architecture (Kubernetes - Namespace `pivot-banking`)

| Component | Port | Service Type | Image / Role |
| :--- | :--- | :--- | :--- |
| `ms-config` | `8888` | `ClusterIP` | `pivot/ms-config:1.0.0` (Spring Cloud Config Server) |
| `ms-eureka` | `8761` | `LoadBalancer` | `pivot/ms-eureka:1.0.0` (Netflix Eureka Discovery Server) |
| `ms-gateway` | `8080` | `LoadBalancer` | `pivot/ms-gateway:1.0.0` (API Gateway + JWT/RBAC + Resilience4j) |
| `ms-auth` | `8085` | `ClusterIP` | `pivot/ms-auth:1.0.0` (HS256 JWT Authentication & BCrypt) |
| `ms-customer` | `8081` | `ClusterIP` | `pivot/ms-customer:1.0.0` (Personal/Business Customers + Redis) |
| `ms-account` | `8082` | `ClusterIP` | `pivot/ms-account:1.0.0` (Accounts, Debit Cards + Kafka Saga) |
| `ms-credit` | `8083` | `ClusterIP` | `pivot/ms-credit:1.0.0` (Loans & Credit Cards) |
| `ms-transaction` | `8084` | `ClusterIP` | `pivot/ms-transaction:1.0.0` (Ledger & Reports + Kafka Consumer) |
| `ms-yanki` | `8086` | `ClusterIP` | `pivot/ms-yanki:1.0.0` (Event-Driven Mobile Wallet + Redis + Kafka) |
| `pivot-mongodb` | `27017` | `ClusterIP` | `mongo:7.0` (Database per Service with 1Gi PVC) |
| `pivot-redis` | `6379` | `ClusterIP` | `redis:7.4-alpine` (Reactive Cache-Aside store) |
| `pivot-kafka` | `9092` | `ClusterIP` | `apache/kafka:3.8.0` (KRaft mode, ZooKeeper-free) |
| `pivot-vault` | `8200` | `ClusterIP` | HashiCorp Vault (AES-256-GCM & JWT secrets at `secret/pivot-bank`) |
| `pivot-loki` | `3100` | `ClusterIP` | `grafana/loki:3.0.0` (Centralized log aggregation) |
| `pivot-grafana` | `3000` | `LoadBalancer` | `grafana/grafana:11.0.0` (Observability dashboards, `admin`/`admin`) |
| `pivot-kafka-ui` | `8090` | `LoadBalancer` | `provectuslabs/kafka-ui:latest` (Kafka topic & event inspector) |
| `pivot-promtail` | N/A | `DaemonSet` | `grafana/promtail:3.0.0` (Container log shipper to Loki) |

**Required startup order:** Infrastructure -> `ms-config` -> `ms-eureka` -> Domain Microservices -> `ms-gateway` -> Observability.

## Repository Structure

| Path / File | Purpose |
| :--- | :--- |
| `k8s/00-namespace.yaml` | Creates the `pivot-banking` Kubernetes namespace. |
| `k8s/01-configmap.yaml` | Shared environment variables (`LOG_PATH`, `JAVA_TOOL_OPTIONS`, internal URLs, health probes). |
| `k8s/02-secrets.yaml` | Cluster-level infrastructure and fallback secrets. |
| `k8s/03-infrastructure.yaml` | Deployments, Services, and PVC for MongoDB, Redis, Kafka (KRaft), and Vault. |
| `k8s/04-platform.yaml` | Deployments and Services for `ms-config` and `ms-eureka`. |
| `k8s/05-microservices.yaml` | Deployments and Services for all 6 business microservices with `startupProbe`, `livenessProbe`, and `readinessProbe`. |
| `k8s/06-gateway.yaml` | Deployment and `LoadBalancer` Service for `ms-gateway` (`:8080`). |
| `k8s/07-observability.yaml` | Deployments and Services for Loki, Grafana, and Kafka UI. |
| `k8s/08-promtail.yaml` | Promtail `DaemonSet` shipping pod logs to Loki. |
| `docker-compose.yml` | Local infrastructure and observability stack (without Kubernetes). |
| `observability/grafana-datasources.yml` | Automated Loki datasource provisioning for Grafana. |
| `observability/promtail-config.yml` | Local file log scraping (`./logs`) for Docker Compose mode. |
| `observability/pivot-banking-grafana-dashboard.json` | Ready-to-import Grafana observability dashboard. |
| `diagrams/Pivot Banking - Master Architecture.drawio` | Master `.drawio` file containing all 15 UML diagrams (architecture, K8s, classes, sequences, ER, and state machines). |
| `1-start-vault.ps1` | Starts native HashiCorp Vault in DEV mode at `http://127.0.0.1:8200`. |
| `2-load-secrets.ps1` | Loads `aes-secret-key`, `jwt-secret-key`, and `jwt-expiration-ms` into `secret/pivot-bank`. |

> **`.gitignore` Note:** The `logs/` directory is excluded from Git to prevent committing local runtime log files.

## Prerequisites
- **Docker Desktop** with **Kubernetes** enabled (*Settings -> Kubernetes -> Enable Kubernetes*) or a compatible container/cluster runtime such as **Podman** (see portability notes).
- **`kubectl`** pointing to the local cluster context:
  ```powershell
  kubectl config use-context docker-desktop
  ```
- **Java 17** and **Apache Maven 3.9+** (if building or running services locally).
- **Postman** to execute the Phase III Master Collection from the `pivot-banking-postman` repository.

## Pre-Deployment Configuration & Customization
Before deploying on a fresh machine, verify the following items:

- **Docker Desktop Resources:** Allocate at least **8 GB RAM and 4 CPUs** (the cluster runs 9 JVMs plus MongoDB, Redis, Kafka, Vault, Loki, Grafana, and Promtail; lower memory may cause slow startups or `OOMKilled` pods).
- **Workspace Folder Layout:** Clone all sibling repositories under the same parent directory before running `docker build` (`pivot-banking-environment`, `pivot-ms-config`, `pviot-ms-eureka`, `pivot-ms-gateway`, `pivot-ms-auth`, `pivot-ms-customer`, `pivot-ms-account`, `pivot-ms-credit`, `pivot-ms-transaction`, and `pivot-ms-yanki`).
- **Required Free Local Ports:** `8080` (Gateway), `8761` (Eureka), `3000` (Grafana), and `8090` (Kafka UI); local Docker Compose mode also uses `27017` (MongoDB), `6379` (Redis), `9092` (Kafka), `8200` (Vault), and `3100` (Loki).
- **Development Secrets & Credentials:** Default dev keys (`VAULT_TOKEN`, 32-byte Base64 `aes-secret-key`, `jwt-secret-key`, and `jwt-expiration-ms`) can be customized in `k8s/02-secrets.yaml` or `2-load-secrets.ps1`. Replace them with externally managed secrets for production environments.
- **Business Rules & Timeouts:** Interest rates, commissions, free monthly movement limits, and the `2s` Circuit Breaker timeout are configurable without recompiling code via `pivot-ms-config` (`src/main/resources/config-data/*.yml`) or environment overrides in `k8s/01-configmap.yaml`.
- **Tooling Quick Import:**
  - **Grafana (`http://localhost:3000`, `admin`/`admin`):** Import `pivot-banking-grafana-dashboard.json` via *Dashboards -> New -> Import* using the pre-provisioned `Loki` datasource.
  - **Postman:** Import the master collection from `pivot-banking-postman`, verify `baseUrl = http://localhost:8080/api/v1`, and run `POST /auth/register` or `POST /auth/login` first (the test script automatically stores the Bearer JWT for all subsequent folders).

## Option A: Full Kubernetes Deployment (Recommended - Phase III)

### 1. Build Docker images (first run or after code changes)
From the parent workspace directory containing all microservice repositories, build the local images with tag `1.0.0`:

```powershell
docker build -t pivot/ms-config:1.0.0      .\pivot-ms-config
docker build -t pivot/ms-eureka:1.0.0      .\pviot-ms-eureka
docker build -t pivot/ms-gateway:1.0.0     .\pivot-ms-gateway
docker build -t pivot/ms-auth:1.0.0        .\pivot-ms-auth
docker build -t pivot/ms-customer:1.0.0    .\pivot-ms-customer
docker build -t pivot/ms-account:1.0.0     .\pivot-ms-account
docker build -t pivot/ms-credit:1.0.0      .\pivot-ms-credit
docker build -t pivot/ms-transaction:1.0.0 .\pivot-ms-transaction
docker build -t pivot/ms-yanki:1.0.0       .\pivot-ms-yanki
```

### 2. Start the cluster in dependency order
From the `pivot-banking-environment` repository root:

```powershell
# 1) Namespace & infrastructure
kubectl apply -f k8s\00-namespace.yaml
kubectl apply -f k8s\03-infrastructure.yaml
kubectl rollout status deployment/pivot-mongodb -n pivot-banking
kubectl rollout status deployment/pivot-redis   -n pivot-banking
kubectl rollout status deployment/pivot-kafka   -n pivot-banking
kubectl rollout status deployment/pivot-vault   -n pivot-banking

# 2) ConfigMap, Secrets & platform (Config Server + Eureka)
kubectl apply -f k8s\01-configmap.yaml
kubectl apply -f k8s\02-secrets.yaml
kubectl apply -f k8s\04-platform.yaml
kubectl rollout status deployment/ms-config -n pivot-banking
kubectl rollout status deployment/ms-eureka -n pivot-banking

# 3) Business microservices & API Gateway
kubectl apply -f k8s\05-microservices.yaml
kubectl apply -f k8s\06-gateway.yaml

$deploys = 'ms-auth','ms-customer','ms-account','ms-credit','ms-transaction','ms-yanki','ms-gateway'
foreach ($d in $deploys) {
  kubectl rollout status "deployment/$d" -n pivot-banking --timeout=420s
}

# 4) Observability (Loki, Grafana, Kafka UI & Promtail DaemonSet)
kubectl apply -f k8s\07-observability.yaml
kubectl apply -f k8s\08-promtail.yaml
```

### 3. Load or verify HashiCorp Vault secrets (optional if using fallback defaults)
To cleanly populate `secret/pivot-bank` inside the `pivot-vault` pod:

```powershell
kubectl exec -n pivot-banking deployment/pivot-vault -- env VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=pivot-bank-dev-token-2026 `
  vault kv put secret/pivot-bank `
  aes-secret-key="UGl2b3RCYW5rU2VjcmV0S2V5MjAyNlNlY3VyZUFfMjU2" `
  jwt-secret-key="UGl2b3RCYW5rSldUU2lnbmluZ1NlY3JldEtleTIwMjZTaGExMjM0NTY3ODkw" `
  jwt-expiration-ms="3600000"
```

### 4. System Verification

```powershell
# Confirm all pods are 1/1 Running
kubectl get pods -n pivot-banking
kubectl get deploy -n pivot-banking

# Check Actuator Health across all Spring services
$svcs = [ordered]@{
  'ms-auth'=8085; 'ms-customer'=8081; 'ms-account'=8082; 'ms-credit'=8083;
  'ms-transaction'=8084; 'ms-yanki'=8086; 'ms-gateway'=8080;
  'ms-eureka'=8761; 'ms-config'=8888
}
foreach ($k in $svcs.Keys) {
  Write-Host "=== $k ===" -ForegroundColor Cyan
  kubectl exec -n pivot-banking deployment/ms-config -- wget -qO- "http://$($k):$($svcs[$k])/actuator/health"
  Write-Host ""
}
```

**Local Web Endpoints:**
- **API Gateway:** `http://localhost:8080/api/v1`
- **Eureka Dashboard:** `http://localhost:8761` (expected: **7 `UP` instances**: `MS-AUTH`, `MS-CUSTOMER`, `MS-ACCOUNT`, `MS-CREDIT`, `MS-TRANSACTION`, `MS-YANKI`, `MS-GATEWAY`)
- **Grafana:** `http://localhost:3000` (default credentials: `admin` / `admin`)
- **Kafka UI:** `http://localhost:8090` (cluster `pivot-banking-cluster`, topics `yanki.payment.requested` and `yanki.payment.result`)

**Quick End-to-End Gateway Smoke Test:**

```powershell
# 1) Register user (public route -> 201 Created)
curl.exe -s -X POST http://localhost:8080/api/v1/auth/register `
  -H "Content-Type: application/json" `
  -d '{"username":"demo","email":"demo@pivot.pe","password":"Pivot2026!","role":"ROLE_ADMIN","customerId":"CUST-001"}'

# 2) Login (public route -> 200 OK with accessToken)
curl.exe -s -X POST http://localhost:8080/api/v1/auth/login `
  -H "Content-Type: application/json" `
  -d '{"username":"demo","password":"Pivot2026!"}'

# 3) Protected route with Bearer JWT (-> 200 OK; missing token returns 401 Unauthorized)
curl.exe -s http://localhost:8080/api/v1/customers -H "Authorization: Bearer <ACCESS_TOKEN>"
```

## How to Pause, Resume, or Tear Down Kubernetes

### Pause the entire stack (preserving MongoDB PVC data)
Scaling all Deployments to `0` stops application and infrastructure pods, but `pivot-promtail` runs as a **`DaemonSet`** and will remain active in Docker Desktop unless explicitly deleted:

```powershell
# Stop all Deployments (keeps PVC, ConfigMaps, and Secrets intact)
kubectl scale deployment -n pivot-banking --all --replicas=0

# Stop the Promtail DaemonSet so no containers remain running
kubectl delete -f k8s\08-promtail.yaml

# Verify no pods remain active
kubectl get pods -n pivot-banking
```

### Resume after a pause

```powershell
# 1) Infrastructure
kubectl scale deployment pivot-mongodb pivot-redis pivot-kafka pivot-vault -n pivot-banking --replicas=1
kubectl rollout status deployment/pivot-mongodb -n pivot-banking
kubectl rollout status deployment/pivot-redis   -n pivot-banking
kubectl rollout status deployment/pivot-kafka   -n pivot-banking
kubectl rollout status deployment/pivot-vault   -n pivot-banking

# 2) Platform
kubectl scale deployment ms-config ms-eureka -n pivot-banking --replicas=1
kubectl rollout status deployment/ms-config -n pivot-banking
kubectl rollout status deployment/ms-eureka -n pivot-banking

# 3) Microservices & Gateway
kubectl scale deployment ms-auth ms-customer ms-account ms-credit ms-transaction ms-yanki ms-gateway -n pivot-banking --replicas=1

# 4) Observability
kubectl scale deployment pivot-loki pivot-grafana pivot-kafka-ui -n pivot-banking --replicas=1
kubectl apply -f k8s\08-promtail.yaml
```

### Full teardown (clean slate)

```powershell
kubectl delete namespace pivot-banking
```

## Option B: Local Development Mode (Docker Compose + Native Vault)
Recommended when debugging a microservice directly from an IDE without rebuilding Docker images:

1. Start infrastructure and observability services:
   ```powershell
   docker compose up -d
   ```
2. Start native HashiCorp Vault in a dedicated terminal (keep open):
   ```powershell
   .\1-start-vault.ps1
   ```
3. Load banking secrets into `secret/pivot-bank` from a second terminal:
   ```powershell
   .\2-load-secrets.ps1
   ```
4. Start Spring Boot microservices locally via `mvn spring-boot:run` in order: `ms-config` (`:8888`) -> `ms-eureka` (`:8761`) -> business microservices -> `ms-gateway` (`:8080`).
5. Shut down local containers:
   ```powershell
   docker compose down
   ```

## Technical Notes, Portability & Troubleshooting
- **Podman Portability:** The Kubernetes manifests (`k8s/*.yaml`) are standard and runtime-agnostic. When running on Podman with `kind` or `minikube`, load the local `pivot/*:1.0.0` images into the cluster node and verify that Promtail uses the matching container log pipeline stage (`- cri: {}` for containerd/CRI-O or `- docker: {}` for Docker Desktop).
- **Spring Boot 4.1.2 / Spring Cloud Gateway 5.0.4:**
  - MongoDB configuration uses `spring.mongodb.uri` (`spring.data.mongodb.*` is deprecated with error level in Boot 4).
  - Gateway routes use `spring.cloud.gateway.server.webflux.*`.
  - Services use `startupProbe` (up to 5 minutes) alongside `/actuator/health/liveness` and `/actuator/health/readiness` to avoid premature restarts when starting multiple JVMs on a single node.
- **Container Log Paths:** The `pivot-config` ConfigMap sets `LOG_PATH=/tmp/pivot-logs` and `JAVA_TOOL_OPTIONS=-DLOG_PATH=/tmp/pivot-logs` to guarantee a writable log directory for non-root container users.
- **2s Circuit Breaker Warm-Up:** The first cold request after pod startup may exceed Resilience4j's `timeoutDuration: 2s` in `ms-gateway` and return a `503` fallback; subsequent requests succeed normally once the JVM warms up.
