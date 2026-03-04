# HPA - Horizontal Pod Autoscaler

## 📄 Archivo: `k8s/biblioteca-hpa.yaml`

## ¿Qué es un HPA?

Un **Horizontal Pod Autoscaler** (HPA) escala automáticamente el número de réplicas de un Deployment basándose en métricas (CPU, memoria, o métricas custom). Es la implementación de auto-scaling en Kubernetes.

## Contenido del Archivo

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: biblioteca-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: biblioteca-cqrs
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

---

## 📋 Explicación Línea por Línea

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
```
- **`autoscaling/v2`**: API de autoscaling (versión 2, con soporte para múltiples métricas)
- **Versión anterior**: `v1` solo soportaba CPU

```yaml
metadata:
  name: biblioteca-hpa
```
- Nombre del HPA

```yaml
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: biblioteca-cqrs
```
- **`scaleTargetRef`**: Referencia al recurso a escalar
- **`kind: Deployment`**: Escalará el Deployment
- **`name: biblioteca-cqrs`**: Nombre del Deployment objetivo

```yaml
  minReplicas: 1
  maxReplicas: 3
```
- **`minReplicas: 1`**: Mínimo número de Pods (nunca baja de esto)
- **`maxReplicas: 3`**: Máximo número de Pods (nunca sube de esto)

💡 **Nota:** Para producción se recomienda `minReplicas: 2` para alta disponibilidad

```yaml
  metrics:
    - type: Resource
      resource:
        name: cpu
```
- **`type: Resource`**: Métrica basada en recursos (CPU o memoria)
- **`name: cpu`**: Usar CPU como métrica

```yaml
        target:
          type: Utilization
          averageUtilization: 70
```
- **`type: Utilization`**: Porcentaje de uso (vs. valor absoluto)
- **`averageUtilization: 70`**: Mantener uso promedio de CPU en 70%

---

## 🎯 Cómo Funciona

### Fórmula de Escalado

```
Réplicas Deseadas = ceil[Réplicas Actuales × (Uso Actual / Uso Objetivo)]
```

**Ejemplo:**
- Réplicas actuales: 1
- CPU actual: 90%
- CPU objetivo: 70%

```
Réplicas Deseadas = ceil[1 × (90 / 70)] = ceil[1.28] = 2
```

El HPA aumentará a 2 réplicas.

### Comportamiento

**Scale Up (Aumentar):**
- Se activa cuando el uso promedio **supera** el objetivo (70%)
- Ejemplo: 90% CPU → Añade réplicas hasta volver a ~70%

**Scale Down (Disminuir):**
- Se activa cuando el uso promedio está **por debajo** del objetivo
- Tiene un **cooldown** (delay) para evitar "flapping"
- Por defecto: espera 5 minutos antes de reducir

**Estabilización:**
- Una vez en el objetivo (±10%), se mantiene el número de réplicas
- HPA verifica cada 15 segundos (configurable)

---

## 🔧 Comandos Útiles

### Aplicar el HPA
```bash
kubectl apply -f k8s/biblioteca-hpa.yaml --context kind-biblioteca-cluster
```

### Ver estado del HPA
```bash
kubectl get hpa --context kind-biblioteca-cluster
```

Salida:
```
NAME            REFERENCE                     TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
biblioteca-hpa  Deployment/biblioteca-cqrs    45%/70%   1         3         1          10m
                                              ↑ Actual / Objetivo
```

### Ver detalles del HPA
```bash
kubectl describe hpa biblioteca-hpa --context kind-biblioteca-cluster
```

### Ver en tiempo real (watch mode)
```bash
kubectl get hpa biblioteca-hpa --watch --context kind-biblioteca-cluster
```

### Ver eventos de escalado
```bash
kubectl describe hpa biblioteca-hpa --context kind-biblioteca-cluster | grep -A 10 Events
```

### Eliminar el HPA
```bash
kubectl delete hpa biblioteca-hpa --context kind-biblioteca-cluster
```

---

## 📊 Métricas Soportadas

### 1. CPU (Actual)
```yaml
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### 2. Memoria
```yaml
metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 3. Múltiples Métricas
```yaml
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
        name: memory
      target:
        type: Utilization
        averageUtilization: 80
```
HPA escalará si **cualquiera** de las métricas excede el objetivo.

### 4. Métricas Custom (Avanzado)
```yaml
metrics:
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
```

---

## ⚙️ Configuración Avanzada

### Cooldown Periods

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: biblioteca-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: biblioteca-cqrs
  minReplicas: 1
  maxReplicas: 3
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Esperar 5 min antes de reducir
      policies:
      - type: Percent
        value: 50            # Reducir máx 50% de réplicas a la vez
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0    # Scale up inmediato
      policies:
      - type: Percent
        value: 100           # Duplicar réplicas si es necesario
        periodSeconds: 15
      - type: Pods
        value: 2             # O añadir máx 2 pods a la vez
        periodSeconds: 15
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

---

## ⚠️ Requisitos Previos

### 1. Metrics Server

El HPA requiere que **Metrics Server** esté instalado:

```bash
# Verificar si está instalado
kubectl get deployment metrics-server -n kube-system --context kind-biblioteca-cluster
```

Si no está instalado:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Para kind, necesita configuración adicional:
kubectl patch -n kube-system deployment metrics-server --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

### 2. Resource Requests

Los Pods **deben** tener `resources.requests` definidos:

```yaml
# En biblioteca-deployment.yaml
resources:
  requests:
    cpu: "200m"      # ← Requerido para HPA
    memory: "512Mi"
```

❌ Sin `requests`, el HPA no puede calcular el porcentaje de uso.

---

## 🧪 Prueba de Carga

Para ver el HPA en acción, genera carga:

### Opción 1: Apache Bench
```bash
# Generar 10000 requests con 100 concurrentes
kubectl port-forward service/biblioteca-service 8089:8089 --context kind-biblioteca-cluster &
ab -n 10000 -c 100 http://localhost:8089/libros/lib-001
```

### Opción 2: Hey
```bash
hey -z 2m -c 50 http://localhost:8089/libros/lib-001
```

### Opción 3: Pod de Carga
```bash
kubectl run load-generator --image=busybox --context kind-biblioteca-cluster -- /bin/sh -c "while true; do wget -q -O- http://biblioteca-service:8089/libros/lib-001; done"

# Ver HPA escalar
kubectl get hpa biblioteca-hpa --watch --context kind-biblioteca-cluster

# Detener carga
kubectl delete pod load-generator --context kind-biblioteca-cluster
```

---

## 📊 Monitorear Escalado

### Ver métricas actuales
```bash
kubectl top pods -l app=biblioteca-cqrs --context kind-biblioteca-cluster
```

Salida:
```
NAME                              CPU(cores)   MEMORY(bytes)
biblioteca-cqrs-5bf5c47dc-xxxxx   150m         450Mi
biblioteca-cqrs-5bf5c47dc-yyyyy   140m         440Mi
```

### Ver histórico de escalado
```bash
kubectl describe hpa biblioteca-hpa --context kind-biblioteca-cluster
```

Buscar en Events:
```
Events:
  Type    Reason             Age    Message
  ----    ------             ----   -------
  Normal  SuccessfulRescale  5m     New size: 2; reason: cpu resource utilization above target
  Normal  SuccessfulRescale  10m    New size: 3; reason: cpu resource utilization above target
  Normal  SuccessfulRescale  20m    New size: 1; reason: All metrics below target
```

---

## 🎯 Comparativa: HPA vs Ejemplo

### Ejemplo (miprimeraapi)
```yaml
minReplicas: 2   # Empieza con 2 réplicas (HA)
maxReplicas: 4   # Hasta 4 réplicas
averageUtilization: 70
```

### Biblioteca CQRS (actual)
```yaml
minReplicas: 1   # Empieza con 1 réplica (demo)
maxReplicas: 3   # Hasta 3 réplicas
averageUtilization: 70
```

**Recomendación para producción:**
```yaml
minReplicas: 2   # Alta disponibilidad
maxReplicas: 5   # Mayor capacidad de escalado
averageUtilization: 60  # Escala antes para evitar saturación
```

---

## 🔗 Referencias

Este HPA gestiona:
- **`biblioteca-deployment.yaml`**: Modifica el número de réplicas automáticamente

**Importante:** Si modificas manualmente las réplicas del Deployment, el HPA las sobreescribirá.

---

## 💡 Mejores Prácticas

1. ✅ **Usar múltiples réplicas mínimas en producción**
   ```yaml
   minReplicas: 2  # No 1
   ```

2. ✅ **Definir requests y limits**
   ```yaml
   resources:
     requests:
       cpu: "200m"
     limits:
       cpu: "500m"
   ```

3. ✅ **Combinar CPU y memoria**
   ```yaml
   metrics:
     - type: Resource
       resource:
         name: cpu
     - type: Resource
       resource:
         name: memory
   ```

4. ✅ **Ajustar cooldown para evitar flapping**
   ```yaml
   behavior:
     scaleDown:
       stabilizationWindowSeconds: 300
   ```

5. ✅ **Monitorear con alertas**
   - Alertar si HPA alcanza maxReplicas (capacidad máxima)
   - Alertar si HPA falla (métricas no disponibles)

---

## 🎓 Conceptos Clave

- **Horizontal Scaling**: Añadir/quitar réplicas (vs. Vertical: cambiar recursos)
- **Auto-scaling**: Escalado automático basado en métricas
- **Cooldown**: Período de espera para evitar cambios frecuentes
- **Target Utilization**: Objetivo de uso de recursos
- **Metrics Server**: Fuente de métricas de recursos
