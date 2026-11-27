# Pivot Banking System - Entorno, Orquestación e Infraestructura (`ENVIROMENT`)

> **Versión en inglés:** [README_EN.md](README_EN.md)

## Descripción General

Repositorio maestro de infraestructura, configuración operativa, observabilidad, diagramas de arquitectura y despliegue en contenedores para **Pivot Banking System** (Fases I, II y III). Centraliza el levantamiento del ecosistema completo de microservicios reactivos (Java 17, Spring Boot 4.1.2, Spring WebFlux, RxJava 3) tanto en **Kubernetes (Docker Desktop)** como en modo de desarrollo local mediante **Docker Compose** y **HashiCorp Vault**.

La observabilidad cubre los tres pilares:

- **Logs:** Promtail -> Loki -> Grafana.
- **Métricas:** derivadas de Loki con LogQL (sin Prometheus).
- **Trazas:** Micrometer Tracing + OpenTelemetry -> Tempo -> Grafana.

## Arquitectura Desplegada (Kubernetes - Namespace `pivot-banking`)

| Componente | Puerto | Tipo de Service | Imagen / Rol |
| :--- | :--- | :--- | :--- |
| `ms-config` | `8888` | `ClusterIP` | `pivot/ms-config:1.0.0` (Spring Cloud Config Server) |
| `ms-eureka` | `8761` | `LoadBalancer` | `pivot/ms-eureka:1.0.0` (Netflix Eureka Discovery Server) |
| `ms-gateway` | `8080` | `LoadBalancer` | `pivot/ms-gateway:1.0.0` (API Gateway + JWT/RBAC + Resilience4j) |
| `ms-auth` | `8085` | `ClusterIP` | `pivot/ms-auth:1.0.0` (Autenticación JWT HS256 y BCrypt) |
| `ms-customer` | `8081` | `ClusterIP` | `pivot/ms-customer:1.0.0` (Clientes Personal/Business + Redis) |
| `ms-account` | `8082` | `ClusterIP` | `pivot/ms-account:1.0.0` (Cuentas, Tarjetas de Débito + Saga Kafka) |
| `ms-credit` | `8083` | `ClusterIP` | `pivot/ms-credit:1.0.0` (Préstamos y Tarjetas de Crédito) |
| `ms-transaction` | `8084` | `ClusterIP` | `pivot/ms-transaction:1.0.0` (Libro Mayor y Reportes + Kafka) |
| `ms-yanki` | `8086` | `ClusterIP` | `pivot/ms-yanki:1.0.0` (Billetera Móvil Event-Driven + Redis + Kafka) |
| `pivot-mongodb` | `27017` | `ClusterIP` | `mongo:7.0` (Database per Service con PVC de 1Gi) |
| `pivot-redis` | `6379` | `ClusterIP` | `redis:7.4-alpine` (Cache-Aside reactivo) |
| `pivot-kafka` | `9092` | `ClusterIP` | `apache/kafka:3.8.0` (Modo KRaft sin ZooKeeper) |
| `pivot-vault` | `8200` | `ClusterIP` | HashiCorp Vault (Secretos AES-256-GCM y JWT en `secret/pivot-bank`) |
| `pivot-loki` | `3100` | `ClusterIP` | `grafana/loki:3.0.0` (Agregación de logs) |
| `pivot-tempo` | `3200`, `4317`, `4318` | `ClusterIP` | `grafana/tempo:2.6.1` (Trazas OTLP; UI/API en `3200`) |
| `pivot-grafana` | `3000` | `LoadBalancer` | `grafana/grafana:11.0.0` (Dashboards y Explore, `admin`/`admin`) |
| `pivot-kafka-ui` | `8090` | `LoadBalancer` | `provectuslabs/kafka-ui:latest` (Inspección de tópicos Kafka) |
| `pivot-promtail` | N/A | `DaemonSet` | `grafana/promtail:3.0.0` (Recolección de logs de pods) |

**Orden obligatorio de arranque:** Infraestructura -> `ms-config` -> `ms-eureka` -> Observabilidad (Tempo/Loki/Grafana/Promtail) -> microservicios de dominio -> `ms-gateway`.

## Estructura del Repositorio

| Ruta / Archivo | Propósito |
| :--- | :--- |
| `k8s/00-namespace.yaml` | Crea el namespace `pivot-banking`. |
| `k8s/01-configmap.yaml` | Variables compartidas (`LOG_PATH`, `JAVA_TOOL_OPTIONS`, `EUREKA_URI`, `CONFIG_SERVER_URI`, URLs internas, health probes). |
| `k8s/02-secrets.yaml` | Secretos de infraestructura y respaldo para el clúster. |
| `k8s/03-infrastructure.yaml` | Deployments, Services y PVC para MongoDB, Redis, Kafka (KRaft) y Vault. |
| `k8s/04-platform.yaml` | Deployments y Services para `ms-config` y `ms-eureka`. |
| `k8s/05-microservices.yaml` | Deployments y Services para los 6 microservicios de negocio con `startupProbe`, `livenessProbe` y `readinessProbe`. |
| `k8s/06-gateway.yaml` | Deployment y Service `LoadBalancer` para `ms-gateway` (`:8080`). |
| `k8s/07-observability.yaml` | Loki, Tempo, Grafana, Kafka UI, datasources y el **dashboard provisionado automáticamente**. |
| `k8s/08-promtail.yaml` | `DaemonSet` de Promtail para enviar los logs de pods hacia Loki. |
| `docker-compose.yml` | Stack local de infraestructura y observabilidad (MongoDB, Redis, Kafka, Loki, Tempo, Promtail y Grafana). |
| `observability/grafana-datasources.yml` | Aprovisionamiento automático de los datasources **Loki** y **Tempo**. |
| `observability/grafana-dashboards.yml` | Provider que carga los dashboards al iniciar Grafana. |
| `observability/promtail-config.yml` | Scraping de `<workspace>/pivot-ms-*/logs/*.log` y `./logs` en Docker Compose. |
| `observability/tempo-config.yml` | Configuración monolítica de Grafana Tempo (OTLP `4317`/`4318`, retención 24 h). |
| `observability/dashboards/pivot-banking-grafana-dashboard.json` | Dashboard de métricas (LogQL) y logs, provisionado automáticamente. |
| `Pivot Banking - Master Architecture.drawio` | Archivo maestro `.drawio` con los 15 diagramas UML. |
| `../Diagram/` | Exportaciones PNG/PDF y documentación de los diagramas. |
| `Pivot Banking - Master Collection.Final.postman_collection.json` | Colección Postman maestra de Fase III. |
| `colecciones/` | Colecciones Postman de Fase II y masters intermedias. |
| `1-start-vault.ps1` | Levanta HashiCorp Vault nativo en modo DEV en `http://127.0.0.1:8200`. |
| `2-load-secrets.ps1` | Carga `aes-secret-key`, `jwt-secret-key` y `jwt-expiration-ms` en `secret/pivot-bank`. |
| `../TRACING-IMPLEMENTATION.md` | Detalle técnico de la implementación de trazas (Tempo/OpenTelemetry). |

> **Nota sobre `.gitignore`:** La carpeta `logs/` se excluye del control de versiones para evitar subir archivos de trazas locales al repositorio.

## Prerrequisitos

- **Docker Desktop** con **Kubernetes** habilitado (*Settings -> Kubernetes -> Enable Kubernetes*) o un motor compatible como **Podman** (ver nota de portabilidad).
- **`kubectl`** apuntando al contexto local:
  ```bash
  kubectl config use-context docker-desktop
  ```
- **Java 17** y **Apache Maven 3.9+** (si se compilan o ejecutan microservicios localmente).
- **Postman** para ejecutar la colección maestra de Fase III.
- **Git Bash / MINGW64** recomendado para los comandos de este README. En Windows también funciona PowerShell, pero **no mezcles sintaxis** de ambos.

## Configuraciones Previas y Personalización

Antes de desplegar en una máquina nueva, verifica estos puntos:

- **Recursos de Docker Desktop:** asigna al menos **8 GB de RAM y 4 CPUs** (el clúster levanta 9 JVMs más MongoDB, Redis, Kafka, Vault, Loki, Tempo, Grafana y Promtail; con menos memoria los pods pueden tardar en arrancar o sufrir `OOMKilled`).
- **Estructura de carpetas del workspace:** clona todos los repositorios hermanos dentro de la misma carpeta padre antes de ejecutar `docker build` (`pivot-ms-config`, `pivot-ms-eureka`, `pivot-ms-gateway`, `pivot-ms-auth`, `pivot-ms-customer`, `pivot-ms-account`, `pivot-ms-credit`, `pivot-ms-transaction` y `pivot-ms-yanki`).
- **Puertos locales requeridos libres:** `8080` (Gateway), `8761` (Eureka), `3000` (Grafana), `8090` (Kafka UI) y `3200` (Tempo, solo si usas `port-forward`); en modo Docker Compose también `27017` (MongoDB), `6379` (Redis), `9092` (Kafka), `8200` (Vault), `3100` (Loki) y `4317`/`4318` (OTLP).
- **Secretos y credenciales de desarrollo:** las claves por defecto (`VAULT_TOKEN`, `aes-secret-key` de 32 bytes en Base64, `jwt-secret-key` y `jwt-expiration-ms`) pueden personalizarse en `k8s/02-secrets.yaml` o `2-load-secrets.ps1`. En entornos productivos deben reemplazarse por secretos gestionados externamente.
- **Reglas de negocio y timeouts:** tasas, comisiones, límites de movimientos gratis y el timeout de `2s` del Circuit Breaker se ajustan sin recompilar código desde `pivot-ms-config` (`src/main/resources/config-data/*.yml`) o sobrescribiendo variables en `k8s/01-configmap.yaml`.
- **Importación de herramientas:**
  - **Grafana (`http://localhost:3000`, `admin`/`admin`):** el dashboard se aprovisiona automáticamente en la carpeta **Pivot Banking** y queda como home por defecto; no requiere importación manual. Los datasources `Loki` y `Tempo` también se crean solos.
  - **Postman:** importa `Pivot Banking - Master Collection.Final.postman_collection.json`, verifica `baseUrl = http://localhost:8080/api/v1` y ejecuta primero `POST /auth/register` o `POST /auth/login` para guardar automáticamente el Bearer JWT.

### Importante: Git Bash vs PowerShell

En **Git Bash / MINGW64**:

- Usa **siempre `/`** en las rutas: `k8s/00-namespace.yaml`, no `k8s\00-namespace.yaml`. La barra invertida escapa el carácter siguiente y termina buscando `k8s00-namespace.yaml`.
- Usa bucles de bash: `for d in ...; do ...; done`. `foreach` y `$deploys` son de PowerShell y **no funcionan** en bash.
- Usa `./pivot-ms-config` para rutas relativas; `.\pivot-ms-config` no funciona en bash.
- Para ejecutar los scripts `.ps1` desde Git Bash:
  ```bash
  powershell.exe -ExecutionPolicy Bypass -File ./1-start-vault.ps1
  powershell.exe -ExecutionPolicy Bypass -File ./2-load-secrets.ps1
  ```

## Opción A: Despliegue Completo en Kubernetes (Recomendado - Fase III)

### 1. Construir las imágenes Docker (primera vez o tras cambios de código)

Desde la **raíz del proyecto** (la carpeta que contiene `ENVIROMENT`, `pivot-ms-config`, etc.):

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

> Si un módulo tiene varios JARs en `target/` (por ejemplo `ms-credit` con `1.0.0` y `1.1.0`), ejecuta `mvn clean package -DskipTests` dentro del módulo o elimina el JAR viejo antes de `docker build`. El Dockerfile copia `target/*.jar`.

### 2. Levantar el clúster en orden de dependencias

Desde `ENVIROMENT`:

```bash
cd "C:/Users/ZER0SEV7N/Documents/Pivot Bootcamp/Proyecto General/ENVIROMENT"

# 1) Namespace, ConfigMap, Secrets e infraestructura
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-configmap.yaml
kubectl apply -f k8s/02-secrets.yaml
kubectl apply -f k8s/03-infrastructure.yaml

kubectl rollout status deployment/pivot-mongodb -n pivot-banking --timeout=240s
kubectl rollout status deployment/pivot-redis   -n pivot-banking --timeout=240s
kubectl rollout status deployment/pivot-kafka   -n pivot-banking --timeout=240s
kubectl rollout status deployment/pivot-vault   -n pivot-banking --timeout=240s

# 2) Plataforma (Config Server + Eureka)
kubectl apply -f k8s/04-platform.yaml
kubectl rollout status deployment/ms-config -n pivot-banking --timeout=240s
kubectl rollout status deployment/ms-eureka -n pivot-banking --timeout=240s

# 3) Observabilidad (Tempo debe estar listo antes de los microservicios)
kubectl apply -f k8s/07-observability.yaml
kubectl apply -f k8s/08-promtail.yaml
kubectl rollout status deployment/pivot-tempo   -n pivot-banking --timeout=240s
kubectl rollout status deployment/pivot-loki    -n pivot-banking --timeout=240s
kubectl rollout status deployment/pivot-grafana -n pivot-banking --timeout=240s
kubectl rollout status daemonset/pivot-promtail -n pivot-banking --timeout=240s

# 4) Microservicios y Gateway
kubectl apply -f k8s/05-microservices.yaml
kubectl apply -f k8s/06-gateway.yaml

for d in ms-auth ms-customer ms-account ms-credit ms-transaction ms-yanki ms-gateway; do
  kubectl rollout status "deployment/$d" -n pivot-banking --timeout=480s
done
```

> **No apliques todo de golpe.** Si los microservicios arrancan antes de `ms-config` y `ms-eureka`, verás `Application run failed` en los logs. Espera cada `rollout status`.

### 3. Cargar o verificar los secretos en HashiCorp Vault (opcional)

Si necesitas recargar limpiamente `secret/pivot-bank` dentro del pod `pivot-vault`:

```bash
kubectl exec -n pivot-banking deployment/pivot-vault -- env VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=pivot-bank-dev-token-2026 vault kv put secret/pivot-bank aes-secret-key="UGl2b3RCYW5rU2VjcmV0S2V5MjAyNlNlY3VyZUFfMjU2" jwt-secret-key="UGl2b3RCYW5rSldUU2lnbmluZ1NlY3JldEtleTIwMjZTaGExMjM0NTY3ODkw" jwt-expiration-ms="3600000"
```

### 4. Verificación y operación

```bash
# Verificar que todos los pods estén 1/1 Running
kubectl get pods -n pivot-banking
kubectl get deploy -n pivot-banking

# Ver el estado en tiempo real
kubectl get pods -n pivot-banking -w
```

**Health checks internos** (usa el pod de `ms-config` como cliente):

```bash
for pair in ms-auth:8085 ms-customer:8081 ms-account:8082 ms-credit:8083 ms-transaction:8084 ms-yanki:8086 ms-gateway:8080 ms-eureka:8761 ms-config:8888; do
  svc="${pair%%:*}"
  port="${pair##*:}"
  echo "=== $svc ==="
  kubectl exec -n pivot-banking deployment/ms-config -- wget -qO- "http://${svc}:${port}/actuator/health"
  echo
done
```

**Accesos web locales:**

| Servicio | URL | Notas |
| :--- | :--- | :--- |
| API Gateway | `http://localhost:8080/api/v1` | Punto de entrada de Postman |
| Eureka Dashboard | `http://localhost:8761` | Deben figurar 7 instancias `UP` |
| Grafana | `http://localhost:3000` | `admin` / `admin` |
| Kafka UI | `http://localhost:8090` | Clúster `pivot-banking-cluster` |
| Tempo API | `http://localhost:3200` | Solo con `kubectl port-forward` |

Si un `LoadBalancer` no responde en Docker Desktop, usa `port-forward`:

```bash
kubectl port-forward -n pivot-banking svc/ms-gateway 8080:8080
kubectl port-forward -n pivot-banking svc/ms-eureka 8761:8761
kubectl port-forward -n pivot-banking svc/pivot-grafana 3000:3000
kubectl port-forward -n pivot-banking svc/pivot-kafka-ui 8090:8090
```

**Prueba rápida End-to-End por Gateway:**

```bash
# 1) Registro de usuario (ruta pública -> 201 Created)
curl.exe -s -X POST http://localhost:8080/api/v1/auth/register -H "Content-Type: application/json" -d '{"username":"demo","email":"demo@pivot.pe","password":"Pivot2026!","role":"ROLE_ADMIN","customerId":"CUST-001"}'

# 2) Login (ruta pública -> 200 OK con accessToken)
curl.exe -s -X POST http://localhost:8080/api/v1/auth/login -H "Content-Type: application/json" -d '{"username":"demo","password":"Pivot2026!"}'

# 3) Ruta protegida con Bearer JWT (-> 200 OK; sin token devuelve 401 Unauthorized)
curl.exe -s http://localhost:8080/api/v1/customers -H "Authorization: Bearer <ACCESS_TOKEN>"
```

> Si el usuario `demo` ya existe, el registro devuelve `409 Conflict`; usa otro `username` o pasa directo al login.

**Ver los microservicios en acción:**

```bash
# Logs en vivo del Gateway y de un servicio
kubectl logs -f deployment/ms-gateway -n pivot-banking
kubectl logs -f deployment/ms-yanki -n pivot-banking

# Estado de los servicios en Eureka
curl.exe -s http://localhost:8761/eureka/apps | grep -E "<name>|<status>"

# Últimos eventos del namespace
kubectl get events -n pivot-banking --sort-by=.lastTimestamp
```

### 5. Conectarse a MongoDB y Redis desde IntelliJ / Redis Insight

MongoDB y Redis son `ClusterIP`. Para verlos desde tu máquina, abre **dos terminales** y déjalas abiertas:

```bash
# Terminal 1 - MongoDB
kubectl port-forward -n pivot-banking svc/pivot-mongodb 27017:27017

# Terminal 2 - Redis
kubectl port-forward -n pivot-banking svc/pivot-redis 6379:6379
```

**IntelliJ Database -> MongoDB:**

| Campo | Valor |
| :--- | :--- |
| Host | `localhost` |
| Port | `27017` |
| Authentication | `None` / `No auth` |
| User / Password | vacíos |
| Database | vacío o `db_pivot_credit`, `db_pivot_customer`, etc. |
| URL | `mongodb://localhost:27017` |

**Redis Insight:**

| Campo | Valor |
| :--- | :--- |
| Host | `localhost` |
| Port | `6379` |
| Database Alias | `pivot-redis-k8s` |
| Username / Password | vacíos |
| TLS | desactivado |

> Las bases `db_pivot_*` aparecen cuando generas tráfico (login, registro, cuentas, etc.). Redis se llena cuando usas Yanki o los flujos con caché.

### 6. Tempo para trazas locales (opcional)

Tempo es `ClusterIP`. Para consultar su API o enviar trazas desde un servicio ejecutado en tu máquina:

```bash
kubectl port-forward -n pivot-banking svc/pivot-tempo 3200:3200 4318:4318
```

Luego, en el servicio local:

```bash
export OTEL_TRACES_ENDPOINT=http://localhost:4318/v1/traces
```

### 7. Pausar, reanudar o eliminar Kubernetes

**Pausar el entorno (conserva PVC, ConfigMaps y Secrets):**

```bash
# Detener todos los Deployments
kubectl scale deployment -n pivot-banking --all --replicas=0

# Detener también el DaemonSet de Promtail
kubectl delete -f k8s/08-promtail.yaml

# Confirmar que no quede ningún pod
kubectl get pods -n pivot-banking
```

**Reanudar tras una pausa:** vuelve a ejecutar la secuencia completa del punto 2 (infraestructura -> plataforma -> servicios -> observabilidad). Es la forma más segura de que `EUREKA_URI`, ConfigMaps y sondas queden actualizados.

**Eliminación completa (borra datos de MongoDB y Tempo):**

```bash
kubectl delete namespace pivot-banking
```

## Opción B: Desarrollo Local (Docker Compose + Vault Nativo)

Útil para depurar un microservicio desde el IDE sin reconstruir imágenes Docker.

1. Levantar infraestructura y observabilidad:
   ```bash
   cd "C:/Users/ZER0SEV7N/Documents/Pivot Bootcamp/Proyecto General/ENVIROMENT"
   docker compose up -d
   docker compose ps
   ```

2. Iniciar HashiCorp Vault nativo en una terminal dedicada (dejar abierta):
   ```bash
   powershell.exe -ExecutionPolicy Bypass -File ./1-start-vault.ps1
   ```

3. Cargar los secretos en `secret/pivot-bank` desde una segunda terminal:
   ```bash
   powershell.exe -ExecutionPolicy Bypass -File ./2-load-secrets.ps1
   ```

4. Iniciar los microservicios localmente con `mvn spring-boot:run` respetando el orden: `ms-config` (`:8888`) -> `ms-eureka` (`:8761`) -> microservicios de negocio -> `ms-gateway` (`:8080`). Usa **una terminal por servicio** (desde `ENVIROMENT`):

   ```bash
   # Terminal 1
   cd ../pivot-ms-config && mvn spring-boot:run

   # Terminal 2
   cd ../pivot-ms-eureka && mvn spring-boot:run

   # Terminal 3
   cd ../pivot-ms-auth && mvn spring-boot:run
   ```

   Para trazas locales, exporta estas variables antes de arrancar cada servicio:

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

   Ajusta `MONGODB_URI` según el servicio (`db_pivot_auth`, `db_pivot_customer`, `db_pivot_account`, `db_pivot_credit`, `db_pivot_transaction`, `db_pivot_yanki`).

5. Apagar el entorno local:
   ```bash
   docker compose down
   ```

> El stack de Docker Compose **no incluye los microservicios**; solo infraestructura y observabilidad. Los servicios se ejecutan desde el IDE o con `mvn spring-boot:run`.

## Observabilidad: Métricas, Logs y Trazas en Grafana

El dashboard **`Pivot Banking · Métricas y Logs (Loki)`** se aprovisiona automáticamente al iniciar Grafana (tanto en Docker Compose como en Kubernetes), queda como *home* por defecto y vive en la carpeta **Pivot Banking**. No hace falta importarlo a mano.

### Métricas derivadas de Loki

No se necesita Prometheus ni modificar los `pom.xml`: Grafana calcula series temporales con **LogQL** sobre los logs que Promtail envía a Loki.

| Panel | Consulta LogQL (resumen) | Para qué sirve |
| :--- | :--- | :--- |
| Eventos de log | `sum(count_over_time({job="pivot-banking", service=~"$service", level=~"$level"}[$__range]))` | Volumen total en el rango |
| Errores (ERROR) | `sum(count_over_time({... level="ERROR"}[$__range]))` | Métrica principal de salud |
| Advertencias (WARN) | `sum(count_over_time({... level="WARN"}[$__range]))` | Degradaciones y reintentos |
| Microservicios reportando | `count(sum by (service) (count_over_time({...}[$__range])))` | Servicios que están logueando |
| Eventos por microservicio | `sum by (service) (count_over_time({...}[1m]))` | Throughput por servicio |
| Errores y warnings por microservicio | `sum by (service) (count_over_time({... level=~"ERROR\|WARN"}[$__range]))` | Localizar el servicio con problemas |

### Logs y correlación por transacción

1. Abre `http://localhost:3000` (`admin` / `admin`) y usa las variables superiores: **Microservicio**, **Nivel** y **Correlation ID / texto**.
2. Pega el `X-Correlation-Id` de una respuesta o de un log para aislar la transacción completa entre Gateway y microservicios.
3. El panel *Logs en vivo* muestra los labels `service`, `level` y `correlationId`; el panel *Últimos errores* queda fijo en `ERROR`.

Consultas manuales en **Explore -> Loki**:

```logql
{job="pivot-banking", service="ms-yanki"} |= "corrId"
{job="pivot-banking", level="ERROR"} |= "BusinessRule"
{service="ms-auth"} |= "<traceId>"
```

### Trazas distribuidas (Tempo)

Cada petición genera una traza completa:

- `ms-gateway` (span servidor HTTP) -> span cliente hacia el microservicio.
- Microservicio destino (span servidor HTTP).
- Llamadas `WebClient` entre servicios (spans hijos).
- Operaciones `find/insert/update/delete` de MongoDB.
- Accesos a Redis y productores/consumidores de Kafka.
- `traceId` y `spanId` en cada línea de log para saltar de la traza a Loki.

En **Explore -> Tempo -> Search** puedes usar TraceQL:

```traceql
{ resource.service.name = "ms-gateway" }
{ name = "http post /api/v1/auth/login" }
{ span.db.system = "mongodb" }
```

Abre una traza y revisa el **waterfall**:

- Spans uno debajo de otro = llamadas **secuenciales**.
- Spans solapados en el tiempo = llamadas **paralelas**.
- `db.system=mongodb` = inserciones/consultas.
- `messaging.system=kafka` = eventos.

Desde un span, usa **Logs for this span** para abrir Loki con el mismo `traceId`.

### Requisito para Docker Compose

Promtail monta el workspace completo en `/workspace` (solo lectura) y busca `<workspace>/pivot-ms-*/logs/*.log`. Ejecuta cada microservicio con su carpeta de módulo como *working directory* (comportamiento por defecto de IntelliJ/VS Code y de `mvn spring-boot:run`), de modo que Logback escriba en `pivot-ms-<servicio>/logs/ms-<servicio>.log`. Si lo ejecutas desde otra ruta, define `-DLOG_PATH=<ruta absoluta>` o copia el `.log` a `ENVIROMENT/logs/`.

En Kubernetes, Promtail lee `/var/log/pods/pivot-banking_*/*/*.log`. Docker Desktop escribe los logs en formato Docker JSON, por eso el pipeline usa `docker: {}`. En un clúster con containerd/CRI, cambia ese stage por `cri: {}` en `k8s/08-promtail.yaml`.

## Notas Técnicas, Portabilidad y Troubleshooting

- **Git Bash:** usa `/` en rutas (`k8s/00-namespace.yaml`), `./` para carpetas (`./pivot-ms-config`) y bucles `for ...; do ...; done`. No uses `\`, `foreach` ni `$deploys`.
- **`Application run failed` en Grafana:** no es un error de Grafana; son microservicios que arrancaron antes de `ms-config`, `ms-eureka`, MongoDB o Kafka. Sigue el orden del punto 2 y espera cada `rollout status`. Cambia el rango del dashboard a **Last 5 minutes** para ocultar errores históricos.
- **`Failed to export spans` (OTLP/Tempo):** el microservicio no pudo enviar spans a `http://pivot-tempo:4318/v1/traces`. Ocurre si Tempo aún no está listo o está escalado a 0. Verifica:
  ```bash
  kubectl get pods -n pivot-banking | grep tempo
  kubectl get endpoints pivot-tempo -n pivot-banking
  kubectl logs deployment/pivot-tempo -n pivot-banking --tail=100
  ```
  Los errores de arranque desaparecen cuando Tempo está `1/1`; cambia el rango de Grafana a **Last 5 minutes**. Para evitarlos, arranca `07`/`08` antes de `05`/`06`.
- **Eureka en `localhost`:** si un servicio intenta registrar en `http://localhost:8761`, verifica que el pod tenga `EUREKA_URI=http://ms-eureka:8761/eureka/`. Los manifiestos `k8s/05` y `k8s/06` ya lo declaran explícitamente y el ConfigMap `pivot-config` también lo contiene.
- **Pod en `0/1`:** revisa:
  ```bash
  kubectl describe pod -l app=ms-credit -n pivot-banking
  kubectl logs deployment/ms-credit -n pivot-banking --tail=200
  kubectl exec -n pivot-banking deployment/ms-credit -- wget -qO- http://localhost:8083/actuator/health/readiness
  ```
- **`ms-credit` con JAR viejo:** si `target/` contiene `ms-credit-1.0.0.jar` y `ms-credit-1.1.0.jar`, elimina el viejo o ejecuta `mvn clean package -DskipTests` antes de reconstruir la imagen.
- **`ImagePullBackOff`:** construye las imágenes locales con los tags `pivot/*:1.0.0` y verifica `imagePullPolicy: IfNotPresent`.
- **`port-forward` no conecta:** confirma que el pod esté `1/1 Running` y que el puerto local no esté ocupado.
- **Grafana muestra errores viejos:** el rango **Last 1 hour** incluye el arranque fallido; usa **Last 5 minutes** o **Last 15 minutes**.
- **Promtail no muestra `service`:** en Docker Desktop el stage debe ser `docker: {}`; en CRI, `cri: {}`. La expresión regular debe terminar en `\s*$` para tolerar el salto de línea.
- **Circuit Breaker de 2 s:** la primera petición en frío tras arrancar un pod puede superar el `timeoutDuration: 2s` de Resilience4j en el Gateway y devolver `503` (fallback); las peticiones siguientes responden normalmente una vez calentada la JVM. **No se modificó esta configuración.**
- **Spring Boot 4.1.2 / Spring Cloud Gateway 5.0.4:** MongoDB utiliza el prefijo `spring.mongodb.uri`; Gateway utiliza `spring.cloud.gateway.server.webflux.*`. Los servicios usan `startupProbe`, `livenessProbe` y `readinessProbe` para evitar reinicios prematuros.
- **Logs en contenedores:** el ConfigMap `pivot-config` define `LOG_PATH=/tmp/pivot-logs` y `JAVA_TOOL_OPTIONS=-DLOG_PATH=/tmp/pivot-logs` para garantizar una ruta escribible bajo usuarios no root.
- **Compatibilidad con Podman:** los manifiestos son estándar; carga las imágenes locales en el nodo y ajusta el parser de Promtail (`cri` vs `docker`) según el runtime.
