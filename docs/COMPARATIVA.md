# Comparativa de Manifiestos: Biblioteca CQRS vs Ejemplo "miprimeraapi"

## 📊 Tabla de Equivalencias

| Ejemplo (miprimeraapi) | Biblioteca CQRS | Función |
|------------------------|-----------------|---------|
| `miprimeraapi-configmap.yaml` | `biblioteca-configmap.yaml` | Variables de entorno y configuración de la aplicación |
| `miprimeraapi-deployment.yaml` | `biblioteca-deployment.yaml` | Definición del Deployment con pods, containers, probes |
| `miprimeraapi-hpa.yaml` | `biblioteca-hpa.yaml` | Horizontal Pod Autoscaler para escalamiento automático |
| `miprimeraapi-secret.yaml` | `biblioteca-secret.yaml` | Secrets con información sensible en base64 |
| `miprimeraapi-service.yaml` | `biblioteca-service.yaml` | Service para exponer la aplicación dentro del cluster |
| `miprimeraapi-ingress.yaml` | **❌ NO TENEMOS** | Ingress para exponer la aplicación externamente |
| **❌ NO TIENEN** | `postgres-deployment.yaml` | Deployment de PostgreSQL en el cluster |
| **❌ NO TIENEN** | `postgres-service.yaml` | Service para PostgreSQL |
| **❌ NO TIENEN** | `postgres-pvc.yaml` | PersistentVolumeClaim para almacenamiento de PostgreSQL |

---

## 🔍 Diferencias Principales

### 1. **Base de Datos**
- **Ejemplo**: Base de datos externa (IP: 67.217.56.24), fuera del cluster
- **Biblioteca CQRS**: PostgreSQL desplegado dentro del cluster con almacenamiento persistente

### 2. **Observabilidad**
- **Ejemplo**: Integración con New Relic mediante:
  - InitContainer que descarga el agente
  - Volume compartido para el agente
  - Variables de entorno para configuración
- **Biblioteca CQRS**: Sin integración de observabilidad (a implementar)

### 3. **Probes**
- **Ejemplo**: Solo `startupProbe` (HTTP GET a `/users`)
- **Biblioteca CQRS**: `livenessProbe` y `readinessProbe` (HTTP GET a `/actuator/health`)

### 4. **Resources**
- **Ejemplo**: Solo define `requests` (200m CPU, 500Mi memoria)
- **Biblioteca CQRS**: Define `requests` y `limits` (requests: 200m CPU/512Mi, limits: 500m CPU/1Gi)

### 5. **Exposición Externa**
- **Ejemplo**: Usa Ingress con NGINX para exponer en ruta `/lavaca`
- **Biblioteca CQRS**: Sin Ingress, acceso mediante port-forward

### 6. **HPA (Horizontal Pod Autoscaler)**
- **Ejemplo**: minReplicas: 2, maxReplicas: 4 (70% CPU)
- **Biblioteca CQRS**: minReplicas: 1, maxReplicas: 3 (70% CPU)

---

## 📋 Análisis Detallado por Componente

### ConfigMap

**Ejemplo:**
```yaml
data:
  NEW_RELIC_APP_NAME: "miprimeraapi"
  NEW_RELIC_LOG: "stdout"
  JAVA_TOOL_OPTIONS: "-javaagent:/opt/newrelic/newrelic/newrelic.jar"
  DB_HOST: "67.217.56.24"
  DB_DATABASE: "prueba"
  DB_USER: "prueba"
  NEW_RELIC_LICENSE_KEY: "..."
```

**Biblioteca CQRS:**
```yaml
data:
  SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-service:5432/library
  SPRING_DATASOURCE_USERNAME: postgres
```

**Diferencias:**
- ✅ Ejemplo incluye configuración de New Relic
- ✅ Ejemplo usa DB externa (IP pública)
- ✅ Biblioteca usa Service DNS interno (postgres-service)
- ⚠️ Ejemplo expone license key en ConfigMap (debería estar en Secret)

---

### Deployment

**Ejemplo:**
```yaml
spec:
  volumes:
    - name: newrelic-agent
      emptyDir: {}
  initContainers:
    - name: download-newrelic-agent
      image: alpine:latest
      command: [descarga agente New Relic]
  containers:
    - startupProbe:
        initialDelaySeconds: 20
        httpGet:
          path: /users
          port: 8080
```

**Biblioteca CQRS:**
```yaml
spec:
  containers:
    - livenessProbe:
        httpGet:
          path: /actuator/health
          port: 8089
        initialDelaySeconds: 30
      readinessProbe:
        httpGet:
          path: /actuator/health
          port: 8089
        initialDelaySeconds: 25
```

**Diferencias:**
- ✅ Ejemplo usa initContainers para preparar el entorno
- ✅ Ejemplo usa volumes para compartir archivos entre containers
- ✅ Biblioteca usa probes más completos (liveness + readiness)
- ✅ Biblioteca define limits y requests de recursos

---

### Secret

**Ejemplo:**
```yaml
data:
  license: TlJBSy03RFQ5NjVHNzE5MDEzMERERkRMTVVEVFJaS1k=
  DB_PASS: cHJ1ZWJh
```

**Biblioteca CQRS:**
```yaml
data:
  SPRING_DATASOURCE_PASSWORD: cG9zdGdyZXM=
```

**Similitudes:**
- Ambos usan base64 encoding
- Ambos son de tipo Opaque

---

### Service

**Ejemplo:**
```yaml
spec:
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 9090        # Puerto del service
      targetPort: 8080  # Puerto del container
```

**Biblioteca CQRS:**
```yaml
spec:
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 8089        # Puerto del service
      targetPort: 8089  # Puerto del container
```

**Similitudes:**
- Ambos usan ClusterIP (acceso interno)
- Mismo tipo de configuración

---

### HPA

**Ejemplo:**
```yaml
spec:
  minReplicas: 2
  maxReplicas: 4
  metrics:
  - type: Resource
    resource: 
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Biblioteca CQRS:**
```yaml
spec:
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

**Diferencias:**
- Ejemplo inicia con 2 réplicas mínimo (alta disponibilidad)
- Biblioteca inicia con 1 réplica (desarrollo/demo)

---

### Ingress (Solo en ejemplo)

**Ejemplo:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: miprimeraapi
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /lavaca(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: miprimeraapi
            port:
              number: 9090
```

**Función:** Expone la aplicación externamente mediante NGINX Ingress Controller en la ruta `/lavaca`

**Biblioteca CQRS:** ❌ No implementado - Se accede mediante `kubectl port-forward`

---

## ✅ Elementos Adicionales de Biblioteca CQRS

### PostgreSQL Deployment
```yaml
# postgres-deployment.yaml
# Despliega PostgreSQL 16 Alpine con volumen persistente
```

### PostgreSQL Service
```yaml
# postgres-service.yaml
# Service interno para conectar la app con la DB
```

### PostgreSQL PVC
```yaml
# postgres-pvc.yaml
# PersistentVolumeClaim de 1Gi para datos de PostgreSQL
```

**Ventajas:**
- ✅ Base de datos completamente containerizada
- ✅ Datos persistentes incluso si el pod se reinicia
- ✅ Arquitectura autocontenida (todo en el cluster)

---

## 🎯 Recomendaciones de Mejora para Biblioteca CQRS

### 1. Agregar Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: biblioteca-ingress
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: biblioteca-service
            port:
              number: 8089
```

### 2. Integrar New Relic
- Agregar initContainer para descargar agente
- Configurar variables de entorno
- Montar volume para el agente

### 3. Mejorar HPA
- Considerar aumentar minReplicas a 2 para alta disponibilidad
- Agregar métricas de memoria además de CPU

### 4. StartupProbe
- Agregar startupProbe para aplicaciones con arranque lento
- Útil para diferenciar entre inicio y operación normal

---

## 📊 Resumen Ejecutivo

| Aspecto | Ejemplo | Biblioteca CQRS | Ganador |
|---------|---------|----------------|---------|
| **Observabilidad** | ✅ New Relic | ❌ No | Ejemplo |
| **Base de Datos** | Externa | ✅ En cluster | Biblioteca |
| **Health Checks** | Básico | ✅ Completo | Biblioteca |
| **Exposición** | ✅ Ingress | Port-forward | Ejemplo |
| **Persistencia** | N/A | ✅ PVC | Biblioteca |
| **Resources** | Requests only | ✅ Requests+Limits | Biblioteca |
| **Seguridad** | License en ConfigMap | ✅ Passwords en Secret | Biblioteca |

---

## 🔧 Próximos Pasos

1. **Implementar Ingress** para acceso externo sin port-forward
2. **Integrar New Relic** para observabilidad y monitoreo
3. **Configurar Helm Charts** para facilitar despliegues
4. **Implementar ArgoCD** para GitOps y CD
5. **Crear Pipeline CI/CD** para automatización completa
