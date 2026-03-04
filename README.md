# Biblioteca CQRS - Despliegue en Kubernetes

Este repositorio contiene los manifiestos de Kubernetes para desplegar la aplicación Biblioteca CQRS en un cluster local usando kind (Kubernetes in Docker).

## 📋 Requisitos Previos

- Docker instalado y corriendo
- `kind` (Kubernetes in Docker) instalado
- `kubectl` instalado y configurado
- Acceso a WSL (si estás en Windows)

## 🏗️ Arquitectura del Despliegue

La aplicación se despliega con los siguientes componentes:

### Base de Datos (PostgreSQL)
- **Deployment**: `postgres-deployment.yaml`
- **Service**: `postgres-service.yaml` (ClusterIP en puerto 5432)
- **PersistentVolumeClaim**: `postgres-pvc.yaml` (1Gi de almacenamiento)
- **Imagen**: `postgres:16-alpine`

### Aplicación (Biblioteca CQRS)
- **Deployment**: `biblioteca-deployment.yaml`
- **Service**: `biblioteca-service.yaml` (ClusterIP en puerto 8089)
- **ConfigMap**: `biblioteca-configmap.yaml`
- **Secret**: `biblioteca-secret.yaml`
- **HPA**: `biblioteca-hpa.yaml` (Horizontal Pod Autoscaler)
- **Imagen**: `leounisabana/biblioteca-cqrs:1.0.2`

## 🚀 Guía de Despliegue Paso a Paso

### 1. Crear el Cluster de Kubernetes con kind

Si aún no tienes un cluster, créalo con:

```bash
wsl kind create cluster --name biblioteca-cluster
```

Verifica que el cluster esté corriendo:

```bash
wsl kubectl cluster-info --context kind-biblioteca-cluster
```

### 2. Desplegar PostgreSQL

Aplica los manifiestos de PostgreSQL en orden:

```bash
# Crear el PersistentVolumeClaim
wsl kubectl apply -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/postgres-pvc.yaml --context kind-biblioteca-cluster

# Desplegar PostgreSQL
wsl kubectl apply -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/postgres-deployment.yaml --context kind-biblioteca-cluster

# Crear el Service
wsl kubectl apply -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/postgres-service.yaml --context kind-biblioteca-cluster
```

Verifica que PostgreSQL esté corriendo:

```bash
wsl kubectl get pods --context kind-biblioteca-cluster
```

Deberías ver algo como:
```
NAME                       READY   STATUS    RESTARTS   AGE
postgres-xxxxxxxxx-xxxxx   1/1     Running   0          30s
```

### 3. Configurar la Aplicación

Aplica el ConfigMap y el Secret:

```bash
# ConfigMap con configuración de base de datos
wsl kubectl apply -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/biblioteca-configmap.yaml --context kind-biblioteca-cluster

# Secret con la contraseña
wsl kubectl apply -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/biblioteca-secret.yaml --context kind-biblioteca-cluster
```

Verifica la configuración:

```bash
wsl kubectl get configmap biblioteca-config -o yaml --context kind-biblioteca-cluster
wsl kubectl get secret biblioteca-secret --context kind-biblioteca-cluster
```

### 4. Desplegar la Aplicación Biblioteca CQRS

```bash
# Desplegar la aplicación
wsl kubectl apply -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/biblioteca-deployment.yaml --context kind-biblioteca-cluster

# Crear el Service
wsl kubectl apply -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/biblioteca-service.yaml --context kind-biblioteca-cluster
```

Espera aproximadamente 30-40 segundos para que la aplicación se inicie completamente:

```bash
wsl kubectl get pods --context kind-biblioteca-cluster -w
```

Presiona `Ctrl+C` cuando veas:
```
NAME                              READY   STATUS    RESTARTS   AGE
biblioteca-cqrs-xxxxxxxxx-xxxxx   1/1     Running   0          45s
postgres-xxxxxxxxx-xxxxx          1/1     Running   0          2m
```

### 5. (Opcional) Configurar Autoscaling

```bash
wsl kubectl apply -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/biblioteca-hpa.yaml --context kind-biblioteca-cluster
```

Verifica el HPA:

```bash
wsl kubectl get hpa --context kind-biblioteca-cluster
```

## 🔍 Verificación del Despliegue

### Verificar todos los recursos

```bash
wsl kubectl get all --context kind-biblioteca-cluster
```

### Ver logs de la aplicación

```bash
# Obtener el nombre del pod
wsl kubectl get pods --context kind-biblioteca-cluster

# Ver logs (reemplaza el nombre del pod)
wsl kubectl logs biblioteca-cqrs-xxxxxxxxx-xxxxx --context kind-biblioteca-cluster --tail=50
```

### Verificar health checks

```bash
wsl kubectl describe pod <nombre-del-pod> --context kind-biblioteca-cluster
```

## 🌐 Acceder a la Aplicación

### Crear Port-Forward

Para acceder a la aplicación desde tu máquina local:

```bash
wsl kubectl port-forward service/biblioteca-service 8089:8089 --context kind-biblioteca-cluster
```

Deja este comando corriendo en una terminal separada.

### Probar los Endpoints

#### 1. Health Check

**PowerShell:**
```powershell
Invoke-RestMethod -Uri http://localhost:8089/actuator/health
```

**Respuesta esperada:**
```json
{
    "status": "UP",
    "groups": ["liveness", "readiness"]
}
```

#### 2. Documentación OpenAPI/Swagger

Abre en tu navegador:
- Swagger UI: http://localhost:8089/swagger-ui.html
- OpenAPI JSON: http://localhost:8089/v3/api-docs

#### 3. Registrar un Libro (Command)

**PowerShell:**
```powershell
$body = '{"id":"lib-001","titulo":"Clean Architecture"}'
Invoke-RestMethod -Uri http://localhost:8089/libros -Method POST -Body $body -ContentType "application/json"
```

#### 4. Consultar un Libro (Query)

**PowerShell:**
```powershell
Invoke-RestMethod -Uri http://localhost:8089/libros/lib-001 -Method GET
```

**Respuesta esperada:**
```
id      titulo             prestado usuarioId
--      ------             -------- ---------
lib-001 Clean Architecture False
```

#### 5. Prestar un Libro (Command)

**PowerShell:**
```powershell
$body = '{"libroId":"lib-001","usuarioId":"user-123"}'
Invoke-RestMethod -Uri http://localhost:8089/libros/prestar -Method POST -Body $body -ContentType "application/json"
```

#### 6. Consultar el Libro Prestado

**PowerShell:**
```powershell
Invoke-RestMethod -Uri http://localhost:8089/libros/lib-001 -Method GET
```

**Respuesta esperada:**
```
id      titulo             prestado usuarioId
--      ------             -------- ---------
lib-001 Clean Architecture True     user-123
```

#### 7. Devolver un Libro (Command)

**PowerShell:**
```powershell
$body = '{"libroId":"lib-001"}'
Invoke-RestMethod -Uri http://localhost:8089/libros/devolver -Method POST -Body $body -ContentType "application/json"
```

## 📊 Monitoreo y Troubleshooting

### Ver el estado general del cluster

```bash
wsl kubectl get all --context kind-biblioteca-cluster
```

### Ver logs en tiempo real

```bash
wsl kubectl logs -f <nombre-del-pod> --context kind-biblioteca-cluster
```

### Verificar eventos del cluster

```bash
wsl kubectl get events --context kind-biblioteca-cluster --sort-by='.lastTimestamp'
```

### Describir un recurso específico

```bash
wsl kubectl describe pod <nombre-del-pod> --context kind-biblioteca-cluster
wsl kubectl describe service biblioteca-service --context kind-biblioteca-cluster
```

### Ver métricas del HPA

```bash
wsl kubectl get hpa --watch --context kind-biblioteca-cluster
```

### Conectarse a la base de datos PostgreSQL

```bash
wsl kubectl exec -it <nombre-del-pod-postgres> --context kind-biblioteca-cluster -- psql -U postgres -d library
```

Dentro de PostgreSQL:
```sql
\dt                          -- Listar tablas
SELECT * FROM libro;         -- Ver todos los libros
\q                           -- Salir
```

## 🔄 Actualizar el Despliegue

Si necesitas actualizar la aplicación con una nueva versión:

1. Actualiza el tag de la imagen en `biblioteca-deployment.yaml`
2. Aplica los cambios:

```bash
wsl kubectl apply -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/biblioteca-deployment.yaml --context kind-biblioteca-cluster
```

3. Verifica el rollout:

```bash
wsl kubectl rollout status deployment/biblioteca-cqrs --context kind-biblioteca-cluster
```

## 🧹 Limpieza

### Eliminar la aplicación

```bash
wsl kubectl delete -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/biblioteca-deployment.yaml --context kind-biblioteca-cluster
wsl kubectl delete -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/biblioteca-service.yaml --context kind-biblioteca-cluster
wsl kubectl delete -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/biblioteca-configmap.yaml --context kind-biblioteca-cluster
wsl kubectl delete -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/biblioteca-secret.yaml --context kind-biblioteca-cluster
wsl kubectl delete -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/biblioteca-hpa.yaml --context kind-biblioteca-cluster
```

### Eliminar PostgreSQL

```bash
wsl kubectl delete -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/postgres-deployment.yaml --context kind-biblioteca-cluster
wsl kubectl delete -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/postgres-service.yaml --context kind-biblioteca-cluster
wsl kubectl delete -f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/k8s/postgres-pvc.yaml --context kind-biblioteca-cluster
```

### Eliminar el cluster completo

```bash
wsl kind delete cluster --name biblioteca-cluster
```

## 📝 Estructura de Archivos

```
k8s/
├── biblioteca-configmap.yaml    # Variables de entorno para la app
├── biblioteca-deployment.yaml   # Deployment de la aplicación
├── biblioteca-hpa.yaml          # Horizontal Pod Autoscaler
├── biblioteca-secret.yaml       # Credenciales (base64)
├── biblioteca-service.yaml      # Service ClusterIP (puerto 8089)
├── postgres-deployment.yaml     # Deployment de PostgreSQL
├── postgres-pvc.yaml            # PersistentVolumeClaim (1Gi)
└── postgres-service.yaml        # Service ClusterIP (puerto 5432)
```

## 🔐 Configuración de Seguridad

El Secret `biblioteca-secret.yaml` contiene la contraseña de PostgreSQL en base64:
- Password en base64: `cG9zdGdyZXM=` (decodifica a "postgres")

**Nota de seguridad:** En producción, usa mecanismos más seguros como:
- Sealed Secrets
- External Secrets Operator
- HashiCorp Vault
- Cloud provider secret managers (AWS Secrets Manager, Azure Key Vault, etc.)

## 🎯 Health Checks Configurados

La aplicación tiene configurados los siguientes health checks:

- **Liveness Probe**: `GET /actuator/health` cada 10s después de 30s
- **Readiness Probe**: `GET /actuator/health` cada 10s después de 25s

Estos endpoints validan:
- Conectividad con la base de datos
- Estado de la aplicación Spring Boot
- Disponibilidad de recursos

## 🔗 Enlaces Relacionados

- Repositorio del código fuente: `D:\Maestria\Arquitectura\Actividad 2\cqrs`
- Docker Hub: https://hub.docker.com/r/leounisabana/biblioteca-cqrs

## 👥 Autor - Actividad 3 K8S


- Leonardo Pérez Ramírez

---

## ✅ Checklist de Verificación

- [ ] Cluster de kind creado y corriendo
- [ ] PostgreSQL desplegado y en estado Running
- [ ] ConfigMap y Secret aplicados
- [ ] Aplicación biblioteca-cqrs desplegada
- [ ] Ambos pods en estado Running (1/1 Ready)
- [ ] Port-forward activo en puerto 8089
- [ ] Health check responde con status "UP"
- [ ] Swagger UI accesible en http://localhost:8089/swagger-ui.html
- [ ] Comando POST /libros funciona correctamente
- [ ] Query GET /libros/{id} funciona correctamente
- [ ] Comando POST /libros/prestar funciona correctamente
- [ ] Comando POST /libros/devolver funciona correctamente