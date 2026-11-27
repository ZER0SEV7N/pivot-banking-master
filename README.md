# Pivot Banking System - Entorno, Orquestación e Infraestructura (`pivot-banking-master`)

> **English version:** [README_EN.md](README_EN.md)

## Descripción General
Repositorio maestro de infraestructura, configuración operativa, observabilidad, diagramas de arquitectura y despliegue en contenedores para **Pivot Banking System** (Fases I, II y III). Centraliza el levantamiento del ecosistema completo de microservicios reactivos (Java 17, Spring Boot 4.1.2, Spring WebFlux, RxJava 3) tanto en **Kubernetes (Docker Desktop)** como en modo de desarrollo local mediante **Docker Compose** y **HashiCorp Vault**.

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
| `pivot-grafana` | `3000` | `LoadBalancer` | `grafana/grafana:11.0.0` (Dashboards de observabilidad, `admin`/`admin`) |
| `pivot-kafka-ui` | `8090` | `LoadBalancer` | `provectuslabs/kafka-ui:latest` (Inspección de tópicos Kafka) |
| `pivot-promtail` | N/A | `DaemonSet` | `grafana/promtail:3.0.0` (Recolección de logs de contenedores) |

**Orden obligatorio de arranque:** Infraestructura -> `ms-config` -> `ms-eureka` -> Microservicios de dominio -> `ms-gateway` -> Observabilidad.

## Estructura del Repositorio

| Ruta / Archivo | Propósito |
| :--- | :--- |
| `k8s/00-namespace.yaml` | Crea el namespace `pivot-banking`. |
| `k8s/01-configmap.yaml` | Variables compartidas (`LOG_PATH`, `JAVA_TOOL_OPTIONS`, URLs internas, health probes). |
| `k8s/02-secrets.yaml` | Secretos de infraestructura y respaldo para el clúster. |
| `k8s/03-infrastructure.yaml` | Deployments, Services y PVC para MongoDB, Redis, Kafka (KRaft) y Vault. |
| `k8s/04-platform.yaml` | Deployments y Services para `ms-config` y `ms-eureka`. |
| `k8s/05-microservices.yaml` | Deployments y Services para los 6 microservicios de negocio con `startupProbe`, `livenessProbe` y `readinessProbe`. |
| `k8s/06-gateway.yaml` | Deployment y Service `LoadBalancer` para `ms-gateway` (`:8080`). |
| `k8s/07-observability.yaml` | Deployments y Services para Loki, Grafana y Kafka UI. |
| `k8s/08-promtail.yaml` | `DaemonSet` de Promtail para enviar los logs de pods hacia Loki. |
| `docker-compose.yml` | Stack local de infraestructura y observabilidad (sin Kubernetes). |
| `observability/grafana-datasources.yml` | Aprovisionamiento automático del datasource Loki en Grafana. |
| `observability/promtail-config.yml` | Configuración de scraping de logs locales (`./logs`) para Docker Compose. |
| `observability/pivot-banking-grafana-dashboard.json` | Dashboard de observabilidad listo para importar en Grafana. |
| `diagrams/Pivot Banking - Master Architecture.drawio` | Archivo maestro `.drawio` con los 15 diagramas UML (arquitectura, K8s, clases, secuencias, ER y estados). |
| `1-start-vault.ps1` | Levanta HashiCorp Vault nativo en modo DEV en `http://127.0.0.1:8200`. |
| `2-load-secrets.ps1` | Carga `aes-secret-key`, `jwt-secret-key` y `jwt-expiration-ms` en `secret/pivot-bank`. |

> **Nota sobre `.gitignore`:** La carpeta `logs/` se excluye del control de versiones para evitar subir archivos de trazas locales al repositorio.

## Prerrequisitos
- **Docker Desktop** con **Kubernetes** habilitado (*Settings -> Kubernetes -> Enable Kubernetes*) o un motor compatible como **Podman** (ver nota de portabilidad).
- **`kubectl`** apuntando al contexto local:
  ```powershell
  kubectl config use-context docker-desktop
  ```
- **Java 17** y **Apache Maven 3.9+** (si se compilan o ejecutan microservicios localmente).
- **Postman** para ejecutar la colección maestra de Fase III desde el repositorio `pivot-banking-postman`.

## Configuraciones Previas y Personalización
Antes de desplegar en una máquina nueva, verifica estos puntos:

- **Recursos de Docker Desktop:** asigna al menos **8 GB de RAM y 4 CPUs** (el clúster levanta 9 JVMs más MongoDB, Redis, Kafka, Vault, Loki, Grafana y Promtail; con menos memoria los pods pueden tardar en arrancar o sufrir `OOMKilled`).
- **Estructura de carpetas del workspace:** clona todos los repositorios hermanos dentro de la misma carpeta padre antes de ejecutar `docker build` (`pivot-banking-environment`, `pivot-ms-config`, `pviot-ms-eureka`, `pivot-ms-gateway`, `pivot-ms-auth`, `pivot-ms-customer`, `pivot-ms-account`, `pivot-ms-credit`, `pivot-ms-transaction` y `pivot-ms-yanki`).
- **Puertos locales requeridos libres:** `8080` (Gateway), `8761` (Eureka), `3000` (Grafana) y `8090` (Kafka UI); en modo Docker Compose local también `27017` (MongoDB), `6379` (Redis), `9092` (Kafka), `8200` (Vault) y `3100` (Loki).
- **Secretos y credenciales de desarrollo:** las claves por defecto (`VAULT_TOKEN`, `aes-secret-key` de 32 bytes en Base64, `jwt-secret-key` y `jwt-expiration-ms`) pueden personalizarse en `k8s/02-secrets.yaml` o `2-load-secrets.ps1`. En entornos productivos deben reemplazarse por secretos gestionados externamente.
- **Reglas de negocio y timeouts:** tasas, comisiones, límites de movimientos gratis y el timeout de `2s` del Circuit Breaker se ajustan sin recompilar código desde `pivot-ms-config` (`src/main/resources/config-data/*.yml`) o sobrescribiendo variables en `k8s/01-configmap.yaml`.
- **Importación de herramientas:**
  - **Grafana (`http://localhost:3000`, `admin`/`admin`):** importa `pivot-banking-grafana-dashboard.json` desde *Dashboards -> New -> Import* usando el datasource `Loki` ya aprovisionado.
  - **Postman:** importa la colección maestra desde `pivot-banking-postman`, verifica `baseUrl = http://localhost:8080/api/v1` y ejecuta primero `POST /auth/register` o `POST /auth/login` para guardar automáticamente el Bearer JWT.

## Opción A: Despliegue Completo en Kubernetes (Recomendado - Fase III)

### 1. Construir las imágenes Docker (primera vez o tras cambios de código)
Desde la carpeta padre que contiene todos los repositorios de microservicios, construye las imágenes locales con el tag `1.0.0`:

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

### 2. Levantar el clúster en orden de dependencias
Desde la raíz de `pivot-banking-environment`:

```powershell
# 1) Namespace e infraestructura
kubectl apply -f k8s\00-namespace.yaml
kubectl apply -f k8s\03-infrastructure.yaml
kubectl rollout status deployment/pivot-mongodb -n pivot-banking
kubectl rollout status deployment/pivot-redis   -n pivot-banking
kubectl rollout status deployment/pivot-kafka   -n pivot-banking
kubectl rollout status deployment/pivot-vault   -n pivot-banking

# 2) ConfigMap, Secrets y plataforma (Config Server + Eureka)
kubectl apply -f k8s\01-configmap.yaml
kubectl apply -f k8s\02-secrets.yaml
kubectl apply -f k8s\04-platform.yaml
kubectl rollout status deployment/ms-config -n pivot-banking
kubectl rollout status deployment/ms-eureka -n pivot-banking

# 3) Microservicios de negocio y API Gateway
kubectl apply -f k8s\05-microservices.yaml
kubectl apply -f k8s\06-gateway.yaml

$deploys = 'ms-auth','ms-customer','ms-account','ms-credit','ms-transaction','ms-yanki','ms-gateway'
foreach ($d in $deploys) {
  kubectl rollout status "deployment/$d" -n pivot-banking --timeout=420s
}

# 4) Observabilidad (Loki, Grafana, Kafka UI y Promtail DaemonSet)
kubectl apply -f k8s\07-observability.yaml
kubectl apply -f k8s\08-promtail.yaml
```

### 3. Cargar o verificar los secretos en HashiCorp Vault (Opcional si usas valores por defecto)
Si necesitas recargar limpiamente `secret/pivot-bank` dentro del pod `pivot-vault`:

```powershell
kubectl exec -n pivot-banking deployment/pivot-vault -- env VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=pivot-bank-dev-token-2026 `
  vault kv put secret/pivot-bank `
  aes-secret-key="UGl2b3RCYW5rU2VjcmV0S2V5MjAyNlNlY3VyZUFfMjU2" `
  jwt-secret-key="UGl2b3RCYW5rSldUU2lnbmluZ1NlY3JldEtleTIwMjZTaGExMjM0NTY3ODkw" `
  jwt-expiration-ms="3600000"
```

### 4. Verificación del sistema

```powershell
# Verificar que todos los pods estén 1/1 Running
kubectl get pods -n pivot-banking
kubectl get deploy -n pivot-banking

# Verificar Actuator Health en todos los servicios
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

**Accesos web locales:**
- **API Gateway:** `http://localhost:8080/api/v1`
- **Eureka Dashboard:** `http://localhost:8761` (deben figurar **7 instancias `UP`**: `MS-AUTH`, `MS-CUSTOMER`, `MS-ACCOUNT`, `MS-CREDIT`, `MS-TRANSACTION`, `MS-YANKI`, `MS-GATEWAY`)
- **Grafana:** `http://localhost:3000` (credenciales por defecto: `admin` / `admin`)
- **Kafka UI:** `http://localhost:8090` (clúster `pivot-banking-cluster`, tópicos `yanki.payment.requested` y `yanki.payment.result`)

**Prueba rápida End-to-End por Gateway:**

```powershell
# 1) Registro de usuario (ruta pública -> 201 Created)
curl.exe -s -X POST http://localhost:8080/api/v1/auth/register `
  -H "Content-Type: application/json" `
  -d '{"username":"demo","email":"demo@pivot.pe","password":"Pivot2026!","role":"ROLE_ADMIN","customerId":"CUST-001"}'

# 2) Login (ruta pública -> 200 OK con accessToken)
curl.exe -s -X POST http://localhost:8080/api/v1/auth/login `
  -H "Content-Type: application/json" `
  -d '{"username":"demo","password":"Pivot2026!"}'

# 3) Ruta protegida con Bearer JWT (-> 200 OK; sin token devuelve 401 Unauthorized)
curl.exe -s http://localhost:8080/api/v1/customers -H "Authorization: Bearer <ACCESS_TOKEN>"
```

## Cómo Pausar, Reanudar o Apagar Kubernetes

### Pausar todo el entorno (sin borrar los datos de MongoDB)
Escalar todos los Deployments a `0` detiene los servicios, pero `pivot-promtail` es un **`DaemonSet`** y seguirá activo en Docker Desktop salvo que también se elimine su manifiesto:

```powershell
# Detener todos los Deployments (conserva PVC y ConfigMaps/Secrets)
kubectl scale deployment -n pivot-banking --all --replicas=0

# Detener también el DaemonSet de Promtail para liberar por completo Docker Desktop
kubectl delete -f k8s\08-promtail.yaml

# Confirmar que no quede ningún pod en ejecución
kubectl get pods -n pivot-banking
```

### Reanudar tras una pausa

```powershell
# 1) Infraestructura
kubectl scale deployment pivot-mongodb pivot-redis pivot-kafka pivot-vault -n pivot-banking --replicas=1
kubectl rollout status deployment/pivot-mongodb -n pivot-banking
kubectl rollout status deployment/pivot-redis   -n pivot-banking
kubectl rollout status deployment/pivot-kafka   -n pivot-banking
kubectl rollout status deployment/pivot-vault   -n pivot-banking

# 2) Plataforma
kubectl scale deployment ms-config ms-eureka -n pivot-banking --replicas=1
kubectl rollout status deployment/ms-config -n pivot-banking
kubectl rollout status deployment/ms-eureka -n pivot-banking

# 3) Microservicios y Gateway
kubectl scale deployment ms-auth ms-customer ms-account ms-credit ms-transaction ms-yanki ms-gateway -n pivot-banking --replicas=1

# 4) Observabilidad
kubectl scale deployment pivot-loki pivot-grafana pivot-kafka-ui -n pivot-banking --replicas=1
kubectl apply -f k8s\08-promtail.yaml
```

### Eliminación completa (limpieza total)

```powershell
kubectl delete namespace pivot-banking
```

## Opción B: Desarrollo Local (Docker Compose + Vault Nativo)
Útil para depurar un microservicio desde el IDE sin reconstruir imágenes Docker:

1. Levantar infraestructura y observabilidad:
   ```powershell
   docker compose up -d
   ```
2. Iniciar HashiCorp Vault nativo en una terminal dedicada (dejar abierta):
   ```powershell
   .\1-start-vault.ps1
   ```
3. Cargar los secretos en `secret/pivot-bank` desde una segunda terminal:
   ```powershell
   .\2-load-secrets.ps1
   ```
4. Iniciar los microservicios localmente con `mvn spring-boot:run` respetando el orden: `ms-config` (`:8888`) -> `ms-eureka` (`:8761`) -> microservicios de negocio -> `ms-gateway` (`:8080`).
5. Para apagar el entorno local:
   ```powershell
   docker compose down
   ```

## Notas Técnicas, Portabilidad y Troubleshooting
- **Compatibilidad con Podman:** Los manifiestos de Kubernetes (`k8s/*.yaml`) son estándar y portables. Si se ejecuta en Podman + `kind`/`minikube` (en lugar de Docker Desktop), basta con cargar las imágenes locales (`pivot/*:1.0.0`) en el nodo del clúster y verificar que Promtail use el parser de logs adecuado (`- cri: {}` en containerd/CRI-O o `- docker: {}` en Docker Desktop).
- **Spring Boot 4.1.2 / Spring Cloud Gateway 5.0.4:**
  - MongoDB utiliza el prefijo `spring.mongodb.uri` (`spring.data.mongodb.*` está deprecado con error en Boot 4).
  - Gateway utiliza el prefijo `spring.cloud.gateway.server.webflux.*`.
  - Los servicios usan `startupProbe` (hasta 5 min) más `livenessProbe` (`/actuator/health/liveness`) y `readinessProbe` (`/actuator/health/readiness`) para evitar reinicios prematuros durante el arranque de múltiples JVM.
- **Logs en contenedores:** El `ConfigMap` `pivot-config` define `LOG_PATH=/tmp/pivot-logs` y `JAVA_TOOL_OPTIONS=-DLOG_PATH=/tmp/pivot-logs` para garantizar una ruta escribible bajo usuarios no root.
- **Circuit Breaker de 2 s:** La primera petición en frío tras arrancar un pod puede superar el `timeoutDuration: 2s` de Resilience4j en el Gateway y devolver `503` (fallback); las peticiones siguientes responden normalmente una vez calentada la JVM.
