# Deployment - biblioteca-cqrs

## 📄 Archivo: `k8s/biblioteca-deployment.yaml`

## ¿Qué es un Deployment?

Un **Deployment** es un objeto de Kubernetes que gestiona un conjunto de Pods idénticos (réplicas). Proporciona actualizaciones declarativas para Pods y ReplicaSets, permitiendo despliegues sin tiempo de inactividad y capacidad de rollback.

## Contenido del Archivo

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: biblioteca-cqrs
  labels:
    app: biblioteca-cqrs
spec:
  replicas: 1
  selector:
    matchLabels:
      app: biblioteca-cqrs
  template:
    metadata:
      labels:
        app: biblioteca-cqrs
    spec:
      containers:
        - name: biblioteca-cqrs
          image: leounisabana/biblioteca-cqrs:1.0.2
          ports:
            - containerPort: 8089
          envFrom:
            - configMapRef:
                name: biblioteca-config
            - secretRef:
                name: biblioteca-secret
          livenessProbe:
            httpGet:
              path: /actuator/health
              port: 8089
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: 8089
            initialDelaySeconds: 25
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          resources:
            requests:
              cpu: "200m"
              memory: "512Mi"
            limits:
              cpu: "500m"
              memory: "1Gi"
```

---

## 📋 Explicación Línea por Línea

### Metadatos API

```yaml
apiVersion: apps/v1
```
- **`apiVersion: apps/v1`**: API de Kubernetes para objetos de aplicaciones
- **`apps/v1`**: Versión estable para Deployments introducida en Kubernetes 1.9

```yaml
kind: Deployment
```
- **`kind`**: Tipo de recurso de Kubernetes
- **`Deployment`**: Controlador que gestiona ReplicaSets y Pods

---

### Metadatos del Deployment

```yaml
metadata:
  name: biblioteca-cqrs
```
- **`name`**: Nombre único del Deployment en el namespace
- Usado para referenciar el Deployment en comandos `kubectl`

```yaml
  labels:
    app: biblioteca-cqrs
```
- **`labels`**: Etiquetas para organizar y seleccionar recursos
- **`app: biblioteca-cqrs`**: Etiqueta de aplicación para identificación

---

### Especificación del Deployment

```yaml
spec:
  replicas: 1
```
- **`replicas`**: Número de instancias (Pods) que deben estar corriendo
- **`1`**: Una sola réplica (para desarrollo/demo)
- Kubernetes mantiene este número de réplicas automáticamente

**💡 Nota:** En producción, se recomienda `replicas: 2` o más para alta disponibilidad.

```yaml
  selector:
    matchLabels:
      app: biblioteca-cqrs
```
- **`selector`**: Define qué Pods son gestionados por este Deployment
- **`matchLabels`**: Criterio de selección basado en etiquetas
- Debe coincidir con las labels del template (línea siguiente)

---

### Template de Pods

```yaml
  template:
    metadata:
      labels:
        app: biblioteca-cqrs
```
- **`template`**: Plantilla para crear Pods
- **`labels`**: Etiquetas que se aplicarán a cada Pod creado
- **Importante:** Estas labels deben coincidir con el `selector.matchLabels`

```yaml
    spec:
      containers:
```
- **`spec`**: Especificación de los Pods
- **`containers`**: Lista de contenedores en el Pod

---

### Configuración del Contenedor

```yaml
        - name: biblioteca-cqrs
```
- **`name`**: Nombre del contenedor dentro del Pod
- Útil cuando hay múltiples contenedores (sidecar pattern)

```yaml
          image: leounisabana/biblioteca-cqrs:1.0.2
```
- **`image`**: Imagen Docker a ejecutar
- **Formato:** `registry/repository:tag`
  - `leounisabana`: Docker Hub username
  - `biblioteca-cqrs`: Nombre del repositorio
  - `1.0.2`: Tag de la versión (incluye Actuator)

```yaml
          ports:
            - containerPort: 8089
```
- **`ports`**: Puertos que el contenedor expone
- **`containerPort: 8089`**: Puerto en el que escucha la aplicación Spring Boot
- **No abre** el puerto externamente, solo documenta

---

### Variables de Entorno

```yaml
          envFrom:
            - configMapRef:
                name: biblioteca-config
```
- **`envFrom`**: Cargar múltiples variables de entorno desde una fuente
- **`configMapRef`**: Referencia a un ConfigMap
- **`name: biblioteca-config`**: Nombre del ConfigMap
- **Resultado:** Todas las claves del ConfigMap se convierten en variables de entorno

```yaml
            - secretRef:
                name: biblioteca-secret
```
- **`secretRef`**: Referencia a un Secret
- **`name: biblioteca-secret`**: Nombre del Secret con datos sensibles
- Variables del Secret también se cargan como env vars

**Variables resultantes:**
- `SPRING_DATASOURCE_URL` (del ConfigMap)
- `SPRING_DATASOURCE_USERNAME` (del ConfigMap)
- `SPRING_DATASOURCE_PASSWORD` (del Secret)

---

### Liveness Probe (Health Check)

```yaml
          livenessProbe:
```
- **`livenessProbe`**: Verifica si el contenedor está **vivo**
- Si falla, Kubernetes **reinicia** el contenedor

```yaml
            httpGet:
              path: /actuator/health
              port: 8089
```
- **`httpGet`**: Realiza una petición HTTP GET
- **`path`**: Endpoint a verificar (proporcionado por Spring Boot Actuator)
- **`port`**: Puerto donde hacer la petición

**Respuesta esperada:** HTTP 200 con `{"status":"UP"}`

```yaml
            initialDelaySeconds: 30
```
- **`initialDelaySeconds`**: Tiempo de espera antes del primer check
- **30 segundos**: Permite que Spring Boot termine de iniciar
- Evita reinicios prematuros durante el arranque

```yaml
            periodSeconds: 10
```
- **`periodSeconds`**: Frecuencia de las verificaciones
- **10 segundos**: Verifica cada 10 segundos

```yaml
            timeoutSeconds: 5
```
- **`timeoutSeconds`**: Tiempo máximo de espera por respuesta
- **5 segundos**: Si tarda más, se considera fallo

```yaml
            failureThreshold: 3
```
- **`failureThreshold`**: Número de fallos consecutivos antes de reiniciar
- **3**: Tres fallos seguidos → Kubernetes reinicia el contenedor

---

### Readiness Probe (Disponibilidad)

```yaml
          readinessProbe:
```
- **`readinessProbe`**: Verifica si el contenedor está **listo** para recibir tráfico
- Si falla, el Pod se **quita del Service** (no recibe tráfico)
- **No reinicia** el contenedor

```yaml
            httpGet:
              path: /actuator/health
              port: 8089
            initialDelaySeconds: 25
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
```
- Misma configuración que livenessProbe pero con `initialDelaySeconds: 25`
- Empieza a verificar 5 segundos antes que liveness
- Permite tiempo para calentar la aplicación

**Diferencia clave:**
- **Liveness** → Reinicia si está muerto
- **Readiness** → Quita tráfico si no está listo (pero no reinicia)

---

### Resources (Recursos)

```yaml
          resources:
            requests:
              cpu: "200m"
              memory: "512Mi"
```
- **`resources`**: Requisitos y límites de recursos del contenedor
- **`requests`**: Recursos **garantizados** por Kubernetes
  - **`cpu: "200m"`**: 200 milicores (0.2 CPUs)
  - **`memory: "512Mi"`**: 512 Mebibytes de RAM

**💡 Nota:** Kubernetes usa estos valores para **scheduler** (decidir en qué nodo colocar el Pod)

```yaml
            limits:
              cpu: "500m"
              memory: "1Gi"
```
- **`limits`**: Máximo de recursos que el contenedor puede usar
  - **`cpu: "500m"`**: Máximo 500 milicores (0.5 CPUs)
  - **`memory: "1Gi"`**: Máximo 1 Gibibyte de RAM

**Comportamiento:**
- **CPU**: Throttling (reduce rendimiento si excede)
- **Memoria**: OOMKilled (mata el proceso si excede)

---

## 🎯 Flujo de Vida del Pod

### 1. Creación
```
Deployment creado → ReplicaSet creado → Pod scheduled → Contenedor pulling image
```

### 2. Inicialización
```
Imagen descargada → Contenedor iniciado → Spring Boot arrancando
```

### 3. Health Checks
```
Esperando 25s → readinessProbe inicia
Esperando 30s → livenessProbe inicia
```

### 4. Ready
```
readinessProbe OK → Pod marcado READY → Añadido al Service → Recibe tráfico
```

### 5. Monitoreo Continuo
```
Cada 10s → readinessProbe verifica
Cada 10s → livenessProbe verifica
```

### 6. Si Falla
```
livenessProbe falla 3 veces → Contador RESTARTS++ → Contenedor reiniciado
readinessProbe falla → Pod removido del Service → Sin tráfico (pero no reinicia)
```

---

## 🔧 Comandos Útiles

### Aplicar el Deployment
```bash
kubectl apply -f k8s/biblioteca-deployment.yaml --context kind-biblioteca-cluster
```

### Ver Deployments
```bash
kubectl get deployments --context kind-biblioteca-cluster
```

### Ver Pods creados por el Deployment
```bash
kubectl get pods -l app=biblioteca-cqrs --context kind-biblioteca-cluster
```

### Describir el Deployment
```bash
kubectl describe deployment biblioteca-cqrs --context kind-biblioteca-cluster
```

### Ver logs del Pod
```bash
# Primero obtener el nombre del pod
kubectl get pods --context kind-biblioteca-cluster

# Ver logs
kubectl logs <nombre-del-pod> --context kind-biblioteca-cluster --tail=100
```

### Ver logs en tiempo real
```bash
kubectl logs -f <nombre-del-pod> --context kind-biblioteca-cluster
```

### Escalar el Deployment
```bash
# Cambiar a 3 réplicas
kubectl scale deployment biblioteca-cqrs --replicas=3 --context kind-biblioteca-cluster
```

### Actualizar la imagen
```bash
kubectl set image deployment/biblioteca-cqrs biblioteca-cqrs=leounisabana/biblioteca-cqrs:1.0.3 --context kind-biblioteca-cluster
```

### Ver estado del rollout
```bash
kubectl rollout status deployment/biblioteca-cqrs --context kind-biblioteca-cluster
```

### Ver historial de revisiones
```bash
kubectl rollout history deployment/biblioteca-cqrs --context kind-biblioteca-cluster
```

### Rollback a versión anterior
```bash
kubectl rollout undo deployment/biblioteca-cqrs --context kind-biblioteca-cluster
```

### Reiniciar el Deployment
```bash
kubectl rollout restart deployment/biblioteca-cqrs --context kind-biblioteca-cluster
```

### Eliminar el Deployment
```bash
kubectl delete deployment biblioteca-cqrs --context kind-biblioteca-cluster
```

---

## 🔄 Estrategias de Actualización

Por defecto, Deployments usan **Rolling Update**:
- Actualiza Pods gradualmente
- Crea nuevos Pods antes de eliminar los antiguos
- Zero downtime

```yaml
# Agregar a spec del Deployment para controlar
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Máx pods extra durante update
      maxUnavailable: 0  # Máx pods no disponibles
```

---

## ⚠️ Consideraciones Importantes

### Probes
- **InitialDelaySeconds** debe ser suficiente para que la app inicie
- **PeriodSeconds** no muy frecuente (consume recursos)
- **FailureThreshold** balance entre sensibilidad y estabilidad

### Resources
- **Requests** muy bajos → Pods lentos
- **Limits** muy bajos → OOMKilled frecuente
- **Requests sin Limits** → Riesgo de consumir todos los recursos del nodo

### Réplicas
- **Producción**: Mínimo 2 réplicas para HA
- **Desarrollo/Demo**: 1 réplica es suficiente
- **Con HPA**: min/max se gestiona automáticamente

---

## 🔗 Referencias en Otros Archivos

Este Deployment interactúa con:
- **`biblioteca-configmap.yaml`**: Variables de entorno
- **`biblioteca-secret.yaml`**: Credenciales
- **`biblioteca-service.yaml`**: Enruta tráfico a los Pods
- **`biblioteca-hpa.yaml`**: Gestiona el número de réplicas

---

## 📊 Diagrama de Relaciones

```
Deployment (biblioteca-cqrs)
    ↓ crea
ReplicaSet (biblioteca-cqrs-5bf5c47dc)
    ↓ gestiona
Pod (biblioteca-cqrs-5bf5c47dc-xxxxx)
    ├── Lee: ConfigMap (biblioteca-config)
    ├── Lee: Secret (biblioteca-secret)
    ├── Health: /actuator/health
    └── Conecta: postgres-service:5432
```

---

## 🎓 Conceptos Clave

- **Declarativo**: Defines el estado deseado, Kubernetes lo mantiene
- **Self-healing**: Reinicia contenedores fallidos automáticamente
- **Rolling Updates**: Actualizaciones sin downtime
- **Resource Management**: Control de CPU y memoria
- **Health Checks**: Monitoreo automático de disponibilidad
