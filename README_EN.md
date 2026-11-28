# Pivot Banking System - Environment, Orchestration & Infrastructure (`ENVIROMENT`)

> **Spanish version:** [README.md](README.md)

## Overview

Master repository for infrastructure, operational configuration, observability, architecture diagrams, and container deployment for **Pivot Banking System** (Phases I, II, and III). It centralizes the full reactive microservices ecosystem (Java 17, Spring Boot 4.1.2, Spring WebFlux, RxJava 3) both on **Kubernetes (Docker Desktop)** and in local development mode with **Docker Compose** and **HashiCorp Vault**.

Observability covers the three pillars:

- **Logs:** Promtail -> Loki -> Grafana.
- **Metrics:** derived from Loki with LogQL (no Prometheus required).
- **Traces:** Micrometer Tracing + OpenTelemetry -> Tempo -> Grafana.

## Deployed Architecture (Kubernetes - Namespace `pivot-banking`)

| Component | Port | Service Type | Image / Role |
| :--- | :--- | :--- | :--- |
| `ms-config` | `8888` | `ClusterIP` | `pivot/ms-config:1.0.0` (Spring Cloud Config Server) |
| `ms-eureka` | `8761` | `LoadBalancer` | `pivot/ms-eureka:1.0.0` (Netflix Eureka Discovery Server) |
| `ms-gateway` | `8080` | `LoadBalancer` | `pivot/ms-gateway:1.0.0` (API Gateway + JWT/RBAC + Resilience4j) |
| `ms-auth` | `8085` | `ClusterIP` | `pivot/ms-auth:1.0.0` (JWT HS256 and BCrypt authentication) |
| `ms-customer` | `8081` | `ClusterIP` | `pivot/ms-customer:1.0.0` (Personal/Business customers + Redis) |
| `ms-account` | `8082` | `ClusterIP` | `pivot/ms-account:1.0.0` (Accounts, Debit Cards + Kafka Saga) |
| `ms-credit` | `8083` | `ClusterIP` | `pivot/ms-credit:1.0.0` (Loans and Credit Cards) |
| `ms-transaction` | `8084` | `ClusterIP` | `pivot/ms-transaction:1.0.0` (Ledger and Reports + Kafka) |
| `ms-yanki` | `8086` | `ClusterIP` | `pivot/ms-yanki:1.0.0` (Event-Driven Mobile Wallet + Redis + Kafka) |
| `pivot-mongodb` | `27017` | `ClusterIP` | `mongo:7.0` (Database per Service with 1Gi PVC) |
| `pivot-redis` | `6379` | `ClusterIP` | `redis:7.4-alpine` (Reactive cache-aside) |
| `pivot-kafka` | `9092` | `ClusterIP` | `apache/kafka:3.8.0` (KRaft mode, no ZooKeeper) |
| `pivot-vault` | `8200` | `ClusterIP` | HashiCorp Vault (AES-256-GCM and JWT secrets in `secret/pivot-bank`) |
| `pivot-loki` | `3100` | `ClusterIP` | `grafana/loki:3.0.0` (Log aggregation) |
| `pivot-tempo` | `3200`, `4317`, `4318` | `ClusterIP` | `grafana/tempo:2.6.1` (OTLP traces; UI/API on `3200`) |
| `pivot-grafana` | `3000` | `LoadBalancer` | `grafana/grafana:11.0.0` (Dashboards and Explore, `admin`/`admin`) |
| `pivot-kafka-ui` | `8090` | `LoadBalancer` | `provectuslabs/kafka-ui:latest` (Kafka topic inspection) |
| `pivot-promtail` | N/A | `DaemonSet` | `grafana/promtail:3.0.0` (Pod log collection) |

**Mandatory startup order:** Infrastructure -> `ms-config` -> `ms-eureka` -> Observability (Tempo/Loki/Grafana/Promtail) -> business microservices -> `ms-gateway`.

## Repository Structure

| Path / File | Purpose |
| :--- | :--- |
| `k8s/00-namespace.yaml` | Creates the `pivot-banking` namespace. |
| `k8s/01-configmap.yaml` | Shared variables (`LOG_PATH`, `JAVA_TOOL_OPTIONS`, `EUREKA_URI`, `CONFIG_SERVER_URI`, internal URLs, health probes). |
| `k8s/02-secrets.yaml` | Infrastructure secrets and cluster fallback values. |
| `k8s/03-infrastructure.yaml` | Deployments, Services, and PVCs for MongoDB, Redis, Kafka (KRaft), and Vault. |
| `k8s/04-platform.yaml` | Deployments and Services for `ms-config` and `ms-eureka`. |
| `k8s/05-microservices.yaml` | Deployments and Services for the six business microservices with `startupProbe`, `livenessProbe`, and `readinessProbe`. |
| `k8s/06-gateway.yaml` | `LoadBalancer` Deployment and Service for `ms-gateway` (`:8080`). |
| `k8s/07-observability.yaml` | Loki, Tempo, Grafana, Kafka UI, datasources, and the **auto-provisioned dashboard**. |
| `k8s/08-promtail.yaml` | Promtail `DaemonSet` that ships pod logs to Loki. |
| `docker-compose.yml` | Local infrastructure and observability stack (MongoDB, Redis, Kafka, Loki, Tempo, Promtail, Grafana). |
| `observability/grafana-datasources.yml` | Auto-provisions the **Loki** and **Tempo** datasources. |
| `observability/grafana-dashboards.yml` | Dashboard provider loaded by Grafana at startup. |
| `observability/promtail-config.yml` | Scrapes `<workspace>/pivot-ms-*/logs/*.log` and `./logs` in Docker Compose. |
| `observability/tempo-config.yml` | Grafana Tempo monolithic configuration (OTLP `4317`/`4318`, 24 h retention). |
| `observability/dashboards/pivot-banking-grafana-dashboard.json` | LogQL metrics and logs dashboard, auto-provisioned. |
| `Pivot Banking - Master Architecture.drawio` | Master `.drawio` file with the 15 UML diagrams. |
| `../Diagram/` | PNG/PDF exports and diagram documentation. |
| `../Diagram/ms-*.drawio` | Per-microservice diagrams: use cases, classes, sequence, and state machines. |
| `Pivot Banking - Master Collection.Final.postman_collection.json` | Phase III master Postman collection. |
| `colecciones/` | Phase II and intermediate master Postman collections. |
| `1-start-vault.ps1` | Starts native HashiCorp Vault in DEV mode at `http://127.0.0.1:8200`. |
| `2-load-secrets.ps1` | Loads `aes-secret-key`, `jwt-secret-key`, and `jwt-expiration-ms` into `secret/pivot-bank`. |
| `../TRACING-IMPLEMENTATION.md` | Technical details of the tracing implementation (Tempo/OpenTelemetry). |

> **`.gitignore` note:** The `logs/` folder is excluded from version control to avoid committing local trace files.

## Prerequisites

- **Docker Desktop** with **Kubernetes** enabled (*Settings -> Kubernetes -> Enable Kubernetes*) or a compatible engine such as **Podman** (see portability note).
- **`kubectl`** pointing to the local context:
  ```bash
  kubectl config use-context docker-desktop
  ```
- **Java 17** and **Apache Maven 3.9+** (if compiling or running microservices locally).
- **Postman** to run the Phase III master collection.
- **Git Bash / MINGW64** recommended for the commands in this README. PowerShell also works on Windows, but **do not mix syntax** from both shells.

## Pre-Deployment Configuration & Customization

Before deploying on a new machine, verify:

- **Docker Desktop resources:** allocate at least **8 GB RAM and 4 CPUs** (the cluster runs 9 JVMs plus MongoDB, Redis, Kafka, Vault, Loki, Tempo, Grafana, and Promtail; with less memory pods may be slow or `OOMKilled`).
- **Workspace folder layout:** clone all sibling repositories under the same parent folder before running `docker build` (`pivot-ms-config`, `pivot-ms-eureka`, `pivot-ms-gateway`, `pivot-ms-auth`, `pivot-ms-customer`, `pivot-ms-account`, `pivot-ms-credit`, `pivot-ms-transaction`, and `pivot-ms-yanki`).
- **Free local ports:** `8080` (Gateway), `8761` (Eureka), `3000` (Grafana), `8090` (Kafka UI), and `3200` (Tempo, only if using `port-forward`); in Docker Compose also `27017` (MongoDB), `6379` (Redis), `9092` (Kafka), `8200` (Vault), `3100` (Loki), and `4317`/`4318` (OTLP).
- **Development secrets:** default values (`VAULT_TOKEN`, Base64 32-byte `aes-secret-key`, `jwt-secret-key`, and `jwt-expiration-ms`) can be customized in `k8s/02-secrets.yaml` or `2-load-secrets.ps1`. Production environments must use externally managed secrets.
- **Business rules and timeouts:** rates, fees, free-transaction limits, and the Circuit Breaker `2s` timeout are adjusted without recompiling code from `pivot-ms-config` (`src/main/resources/config-data/*.yml`) or by overriding variables in `k8s/01-configmap.yaml`.
- **Tool setup:**
  - **Grafana (`http://localhost:3000`, `admin`/`admin`):** the dashboard is auto-provisioned in the **Pivot Banking** folder and set as home; no manual import is needed. The `Loki` and `Tempo` datasources are also created automatically.
  - **Postman:** import `Pivot Banking - Master Collection.Final.postman_collection.json`, verify `baseUrl = http://localhost:8080/api/v1`, and run `POST /auth/register` or `POST /auth/login` first to store the Bearer JWT automatically.

### Important: Git Bash vs PowerShell

In **Git Bash / MINGW64**:

- **Always use `/`** in paths: `k8s/00-namespace.yaml`, not `k8s\00-namespace.yaml`. A backslash escapes the next character and makes kubectl look for `k8s00-namespace.yaml`.
- Use bash loops: `for d in ...; do ...; done`. `foreach` and `$deploys` are PowerShell-only and **do not work** in bash.
- Use `./pivot-ms-config` for relative paths; `.\pivot-ms-config` does not work in bash.
- To run the `.ps1` scripts from Git Bash:
  ```bash
  powershell.exe -ExecutionPolicy Bypass -File ./1-start-vault.ps1
  powershell.exe -ExecutionPolicy Bypass -File ./2-load-secrets.ps1
  ```

## Option A: Full Kubernetes Deployment (Recommended - Phase III)

### 1. Build Docker images (first run or after code changes)

From the **project root** (the folder containing `ENVIROMENT`, `pivot-ms-config`, etc.):

```bash
cd "C:/Users/ZER0SEV7N/Documents/Pivot Bootcamp/Proyecto General"

docker build -t pivot/ms-config:1.0.0      ./pivot-ms-config
docker build -t pivot/ms-eureka:1.0.0      ./pivot-ms-eureka
docker build -t pivot/ms-gateway:1.0.0     ./pivot-ms-gateway
docker build -t pivot/ms-auth:1.0.0        ./pivot-ms-auth
docker build -t pivot/ms-customer:1.0.0    ./pivot-ms-customer
docker build -t pivot/ms-account:1.0.0     ./pivot-ms-account
docker build -t pivot/ms-credit:1.0.0      ./pivot-ms-credit
docker build -t pivot/ms-transaction:1.0.0 ./pivot-ms-transaction
docker build -t pivot/ms-yanki:1.0.0       ./pivot-ms-yanki
```

> If a module has multiple JARs in `target/` (for example `ms-credit` with `1.0.0` and `1.1.0`), run `mvn clean package -DskipTests` inside the module or remove the stale JAR before `docker build`. The Dockerfile copies `target/*.jar`.

### 2. Start the cluster in dependency order

From `ENVIROMENT`:

```bash
cd "C:/Users/ZER0SEV7N/Documents/Pivot Bootcamp/Proyecto General/ENVIROMENT"

# 1) Namespace, ConfigMap, Secrets, and infrastructure
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-configmap.yaml
kubectl apply -f k8s/02-secrets.yaml
kubectl apply -f k8s/03-infrastructure.yaml

kubectl rollout status deployment/pivot-mongodb -n pivot-banking --timeout=240s
kubectl rollout status deployment/pivot-redis   -n pivot-banking --timeout=240s
kubectl rollout status deployment/pivot-kafka   -n pivot-banking --timeout=240s
kubectl rollout status deployment/pivot-vault   -n pivot-banking --timeout=240s

# 2) Platform (Config Server + Eureka)
kubectl apply -f k8s/04-platform.yaml
kubectl rollout status deployment/ms-config -n pivot-banking --timeout=240s
kubectl rollout status deployment/ms-eureka -n pivot-banking --timeout=240s

# 3) Observability (Tempo must be ready before the microservices)
kubectl apply -f k8s/07-observability.yaml
kubectl apply -f k8s/08-promtail.yaml
kubectl rollout status deployment/pivot-tempo   -n pivot-banking --timeout=240s
kubectl rollout status deployment/pivot-loki    -n pivot-banking --timeout=240s
kubectl rollout status deployment/pivot-grafana -n pivot-banking --timeout=240s
kubectl rollout status daemonset/pivot-promtail -n pivot-banking --timeout=240s

# 4) Microservices and Gateway
kubectl apply -f k8s/05-microservices.yaml
kubectl apply -f k8s/06-gateway.yaml

for d in ms-auth ms-customer ms-account ms-credit ms-transaction ms-yanki ms-gateway; do
  kubectl rollout status "deployment/$d" -n pivot-banking --timeout=480s
done
```

> **Do not apply everything at once.** If microservices start before `ms-config` and `ms-eureka`, logs will show `Application run failed`. Wait for each `rollout status`.

### 3. Load or verify HashiCorp Vault secrets (optional)

To cleanly reload `secret/pivot-bank` inside the `pivot-vault` pod:

```bash
kubectl exec -n pivot-banking deployment/pivot-vault -- env VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=pivot-bank-dev-token-2026 vault kv put secret/pivot-bank aes-secret-key="UGl2b3RCYW5rU2VjcmV0S2V5MjAyNlNlY3VyZUFfMjU2" jwt-secret-key="UGl2b3RCYW5rSldUU2lnbmluZ1NlY3JldEtleTIwMjZTaGExMjM0NTY3ODkw" jwt-expiration-ms="3600000"
```

### 4. Verification and operation

```bash
# Confirm all pods are 1/1 Running
kubectl get pods -n pivot-banking
kubectl get deploy -n pivot-banking

# Watch status in real time
kubectl get pods -n pivot-banking -w
```

**Internal health checks** (uses the `ms-config` pod as the HTTP client):

```bash
for pair in ms-auth:8085 ms-customer:8081 ms-account:8082 ms-credit:8083 ms-transaction:8084 ms-yanki:8086 ms-gateway:8080 ms-eureka:8761 ms-config:8888; do
  svc="${pair%%:*}"
  port="${pair##*:}"
  echo "=== $svc ==="
  kubectl exec -n pivot-banking deployment/ms-config -- wget -qO- "http://${svc}:${port}/actuator/health"
  echo
done
```

**Local web access:**

| Service | URL | Notes |
| :--- | :--- | :--- |
| API Gateway | `http://localhost:8080/api/v1` | Postman entry point |
| Eureka Dashboard | `http://localhost:8761` | 7 instances should be `UP` |
| Grafana | `http://localhost:3000` | `admin` / `admin` |
| Kafka UI | `http://localhost:8090` | Cluster `pivot-banking-cluster` |
| Tempo API | `http://localhost:3200` | Only with `kubectl port-forward` |

If a `LoadBalancer` does not respond on Docker Desktop, use `port-forward`:

```bash
kubectl port-forward -n pivot-banking svc/ms-gateway 8080:8080
kubectl port-forward -n pivot-banking svc/ms-eureka 8761:8761
kubectl port-forward -n pivot-banking svc/pivot-grafana 3000:3000
kubectl port-forward -n pivot-banking svc/pivot-kafka-ui 8090:8090
```

**Quick End-to-End test through the Gateway:**

```bash
# 1) User registration (public route -> 201 Created)
curl.exe -s -X POST http://localhost:8080/api/v1/auth/register -H "Content-Type: application/json" -d '{"username":"demo","email":"demo@pivot.pe","password":"Pivot2026!","role":"ROLE_ADMIN","customerId":"CUST-001"}'

# 2) Login (public route -> 200 OK with accessToken)
curl.exe -s -X POST http://localhost:8080/api/v1/auth/login -H "Content-Type: application/json" -d '{"username":"demo","password":"Pivot2026!"}'

# 3) Protected route with Bearer JWT (-> 200 OK; missing token returns 401 Unauthorized)
curl.exe -s http://localhost:8080/api/v1/customers -H "Authorization: Bearer <ACCESS_TOKEN>"
```

> If user `demo` already exists, registration returns `409 Conflict`; use another `username` or go straight to login.

**See the microservices in action:**

```bash
# Live Gateway and service logs
kubectl logs -f deployment/ms-gateway -n pivot-banking
kubectl logs -f deployment/ms-yanki -n pivot-banking

# Eureka service status
curl.exe -s http://localhost:8761/eureka/apps | grep -E "<name>|<status>"

# Latest namespace events
kubectl get events -n pivot-banking --sort-by=.lastTimestamp
```

### 5. Connect to MongoDB and Redis from IntelliJ / Redis Insight

MongoDB and Redis are `ClusterIP`. Open **two terminals** and keep them open:

```bash
# Terminal 1 - MongoDB
kubectl port-forward -n pivot-banking svc/pivot-mongodb 27017:27017

# Terminal 2 - Redis
kubectl port-forward -n pivot-banking svc/pivot-redis 6379:6379
```

**IntelliJ Database -> MongoDB:**

| Field | Value |
| :--- | :--- |
| Host | `localhost` |
| Port | `27017` |
| Authentication | `None` / `No auth` |
| User / Password | empty |
| Database | empty or `db_pivot_credit`, `db_pivot_customer`, etc. |
| URL | `mongodb://localhost:27017` |

**Redis Insight:**

| Field | Value |
| :--- | :--- |
| Host | `localhost` |
| Port | `6379` |
| Database Alias | `pivot-redis-k8s` |
| Username / Password | empty |
| TLS | disabled |

> `db_pivot_*` databases appear when you generate traffic (login, registration, accounts, etc.). Redis fills up when you use Yanki or cache-backed flows.

### 6. Tempo for local traces (optional)

Tempo is `ClusterIP`. To query its API or send traces from a service running on your machine:

```bash
kubectl port-forward -n pivot-banking svc/pivot-tempo 3200:3200 4318:4318
```

Then, in the local service:

```bash
export OTEL_TRACES_ENDPOINT=http://localhost:4318/v1/traces
```

### 7. Pause, resume, or tear down Kubernetes

**Pause the stack (preserves PVCs, ConfigMaps, and Secrets):**

```bash
# Stop all Deployments
kubectl scale deployment -n pivot-banking --all --replicas=0

# Also stop the Promtail DaemonSet
kubectl delete -f k8s/08-promtail.yaml

# Confirm no pods remain
kubectl get pods -n pivot-banking
```

**Resume after a pause:** re-run the full sequence from step 2 (infrastructure -> platform -> services -> observability). This is the safest way to refresh `EUREKA_URI`, ConfigMaps, and probes.

**Full teardown (deletes MongoDB and Tempo data):**

```bash
kubectl delete namespace pivot-banking
```

## Option B: Local Development Mode (Docker Compose + Native Vault)

Useful for debugging a microservice from the IDE without rebuilding Docker images.

1. Start infrastructure and observability:
   ```bash
   cd "C:/Users/ZER0SEV7N/Documents/Pivot Bootcamp/Proyecto General/ENVIROMENT"
   docker compose up -d
   docker compose ps
   ```

2. Start native HashiCorp Vault in a dedicated terminal (keep it open):
   ```bash
   powershell.exe -ExecutionPolicy Bypass -File ./1-start-vault.ps1
   ```

3. Load secrets into `secret/pivot-bank` from a second terminal:
   ```bash
   powershell.exe -ExecutionPolicy Bypass -File ./2-load-secrets.ps1
   ```

4. Start the microservices locally with `mvn spring-boot:run` in this order: `ms-config` (`:8888`) -> `ms-eureka` (`:8761`) -> business microservices -> `ms-gateway` (`:8080`). Use **one terminal per service** (from `ENVIROMENT`):

   ```bash
   # Terminal 1
   cd ../pivot-ms-config && mvn spring-boot:run

   # Terminal 2
   cd ../pivot-ms-eureka && mvn spring-boot:run

   # Terminal 3
   cd ../pivot-ms-auth && mvn spring-boot:run
   ```

   For local traces, export these variables before starting each service:

   ```bash
   export CONFIG_SERVER_URI=http://localhost:8888
   export EUREKA_URI=http://localhost:8761/eureka/
   export MONGODB_URI=mongodb://localhost:27017/db_pivot_credit
   export REDIS_HOST=localhost
   export REDIS_PORT=6379
   export KAFKA_BOOTSTRAP_SERVERS=localhost:9092
   export VAULT_URI=http://localhost:8200
   export OTEL_TRACES_ENDPOINT=http://localhost:4318/v1/traces
   ```

   Adjust `MONGODB_URI` per service (`db_pivot_auth`, `db_pivot_customer`, `db_pivot_account`, `db_pivot_credit`, `db_pivot_transaction`, `db_pivot_yanki`).

5. Shut down the local stack:
   ```bash
   docker compose down
   ```

> Docker Compose **does not include the microservices**; it only provides infrastructure and observability. Run services from the IDE or with `mvn spring-boot:run`.

## Observability: Metrics, Logs, and Traces in Grafana

The **`Pivot Banking · Métricas y Logs (Loki)`** dashboard is auto-provisioned when Grafana starts (both Docker Compose and Kubernetes), set as the default home, and stored in the **Pivot Banking** folder. No manual import is needed.

### Loki-derived metrics

No Prometheus or `pom.xml` changes are required: Grafana computes time series with **LogQL** over the logs Promtail sends to Loki.

| Panel | LogQL query (summary) | Purpose |
| :--- | :--- | :--- |
| Log events | `sum(count_over_time({job="pivot-banking", service=~"$service", level=~"$level"}[$__range]))` | Total volume in the range |
| Errors (ERROR) | `sum(count_over_time({... level="ERROR"}[$__range]))` | Primary health metric |
| Warnings (WARN) | `sum(count_over_time({... level="WARN"}[$__range]))` | Degradations and retries |
| Reporting services | `count(sum by (service) (count_over_time({...}[$__range])))` | Services currently logging |
| Events per service | `sum by (service) (count_over_time({...}[1m]))` | Throughput per service |
| Errors and warnings per service | `sum by (service) (count_over_time({... level=~"ERROR\|WARN"}[$__range]))` | Locate the problematic service |

### Logs and transaction correlation

1. Open `http://localhost:3000` (`admin` / `admin`) and use the top variables: **Service**, **Level**, and **Correlation ID / text**.
2. Paste the `X-Correlation-Id` from a response or log to isolate the full transaction across Gateway and microservices.
3. The *Live logs* panel shows the `service`, `level`, and `correlationId` labels; the *Latest errors* panel is fixed to `ERROR`.

Manual queries in **Explore -> Loki**:

```logql
{job="pivot-banking", service="ms-yanki"} |= "corrId"
{job="pivot-banking", level="ERROR"} |= "BusinessRule"
{service="ms-auth"} |= "<traceId>"
```

### Distributed traces (Tempo)

Each request produces a complete trace:

- `ms-gateway` HTTP server span -> HTTP client span to the target microservice.
- Target microservice HTTP server span.
- `WebClient` calls between services (child spans).
- MongoDB `find/insert/update/delete` operations.
- Redis accesses and Kafka producer/consumer spans.
- `traceId` and `spanId` in every log line to jump from a trace to Loki.

In **Explore -> Tempo -> Search**, use TraceQL:

```traceql
{ resource.service.name = "ms-gateway" }
{ name = "http post /api/v1/auth/login" }
{ span.db.system = "mongodb" }
```

Open a trace and inspect the **waterfall**:

- Spans one after another = **sequential** calls.
- Overlapping spans = **parallel** calls.
- `db.system=mongodb` = inserts/queries.
- `messaging.system=kafka` = events.

From a span, use **Logs for this span** to open Loki with the same `traceId`.

### Docker Compose requirement

Promtail mounts the full workspace at `/workspace` (read-only) and looks for `<workspace>/pivot-ms-*/logs/*.log`. Run each microservice with its module folder as the *working directory* (default behavior in IntelliJ/VS Code and `mvn spring-boot:run`), so Logback writes to `pivot-ms-<service>/logs/ms-<service>.log`. If you run it from another path, set `-DLOG_PATH=<absolute-path>` or copy the `.log` file to ``.

In Kubernetes, Promtail reads `/var/log/pods/pivot-banking_*/*/*.log`. Docker Desktop writes Docker JSON logs, so the pipeline uses `docker: {}`. On a containerd/CRI cluster, replace that stage with `cri: {}` in `k8s/08-promtail.yaml`.

## Technical Notes, Portability & Troubleshooting

- **Git Bash:** use `/` in paths (`k8s/00-namespace.yaml`), `./` for folders (`./pivot-ms-config`), and `for ...; do ...; done` loops. Do not use `\`, `foreach`, or `$deploys`.
- **`Application run failed` in Grafana:** this is not a Grafana error; microservices started before `ms-config`, `ms-eureka`, MongoDB, or Kafka were ready. Follow the order in step 2 and wait for each `rollout status`. Change the dashboard range to **Last 5 minutes** to hide historical errors.
- **`Failed to export spans` (OTLP/Tempo):** the microservice could not send spans to `http://pivot-tempo:4318/v1/traces`. This happens when Tempo is not ready or is scaled to 0. Check:
  ```bash
  kubectl get pods -n pivot-banking | grep tempo
  kubectl get endpoints pivot-tempo -n pivot-banking
  kubectl logs deployment/pivot-tempo -n pivot-banking --tail=100
  ```
  Startup errors disappear once Tempo is `1/1`; change the Grafana range to **Last 5 minutes**. To avoid them, start `07`/`08` before `05`/`06`.
- **Eureka on `localhost`:** if a service tries to register at `http://localhost:8761`, verify the pod has `EUREKA_URI=http://ms-eureka:8761/eureka/`. `k8s/05` and `k8s/06` already declare it explicitly, and the `pivot-config` ConfigMap also contains it.
- **Pod stuck at `0/1`:** check:
  ```bash
  kubectl describe pod -l app=ms-credit -n pivot-banking
  kubectl logs deployment/ms-credit -n pivot-banking --tail=200
  kubectl exec -n pivot-banking deployment/ms-credit -- wget -qO- http://localhost:8083/actuator/health/readiness
  ```
- **`ms-credit` using a stale JAR:** if `target/` contains both `ms-credit-1.0.0.jar` and `ms-credit-1.1.0.jar`, remove the old one or run `mvn clean package -DskipTests` before rebuilding the image.
- **`ImagePullBackOff`:** build local images with `pivot/*:1.0.0` tags and verify `imagePullPolicy: IfNotPresent`.
- **`port-forward` cannot connect:** confirm the pod is `1/1 Running` and the local port is free.
- **Grafana shows old errors:** the **Last 1 hour** range includes the failed startup; use **Last 5 minutes** or **Last 15 minutes**.
- **Promtail does not show `service`:** on Docker Desktop the stage must be `docker: {}`; on CRI, use `cri: {}`. The regular expression must end with `\s*$` to tolerate the trailing newline.
- **2 s Circuit Breaker:** the first cold request after a pod starts may exceed Resilience4j's `timeoutDuration: 2s` in the Gateway and return `503` (fallback); subsequent requests respond normally once the JVM is warm. **This configuration was not modified.**
- **Spring Boot 4.1.2 / Spring Cloud Gateway 5.0.4:** MongoDB uses the `spring.mongodb.uri` prefix; Gateway uses `spring.cloud.gateway.server.webflux.*`. Services use `startupProbe`, `livenessProbe`, and `readinessProbe` to avoid premature restarts.
- **Container logs:** the `pivot-config` ConfigMap sets `LOG_PATH=/tmp/pivot-logs` and `JAVA_TOOL_OPTIONS=-DLOG_PATH=/tmp/pivot-logs` to guarantee a writable path under non-root users.
- **Podman compatibility:** manifests are standard; load local images into the node and adjust the Promtail parser (`cri` vs `docker`) for the runtime.
