# New Relic - Observabilidad y Monitoreo

## 🔍 ¿Qué es New Relic?

**New Relic** es una plataforma de observabilidad que proporciona monitoreo de aplicaciones (APM), infraestructura, logs y métricas en tiempo real. Permite detectar problemas, analizar rendimiento y optimizar aplicaciones.

## 📊 Información de tu Cuenta

**Datos proporcionados:**
- **License Key**: `NRAK-ADZY09RSDEN0601BUBK6GQMLNBS`
- **Key Name**: `biblioteca_key`
- **Account ID**: `7785285`
- **Email**: `yesidpera@unisabana.edu.co`
- **Key Type**: USER

---

## 🔧 Integración con Biblioteca CQRS

### Estrategia: InitContainer + Volume Mount

Siguiendo el patrón del ejemplo `miprimeraapi`, usaremos:
1. **InitContainer**: Descarga el agente de New Relic
2. **EmptyDir Volume**: Comparte el agente entre containers
3. **Java Agent**: Inyecta el agente en la JVM

---

## 📄 Manifiestos Actualizados

### 1. biblioteca-configmap.yaml (Actualizado)

Agregar configuración de New Relic:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: biblioteca-config
data:
  # Database Configuration
  SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-service:5432/library
  SPRING_DATASOURCE_USERNAME: postgres
  
  # New Relic Configuration
  NEW_RELIC_APP_NAME: "biblioteca-cqrs"
  NEW_RELIC_LOG: "stdout"
  NEW_RELIC_LOG_LEVEL: "info"
  JAVA_TOOL_OPTIONS: "-javaagent:/opt/newrelic/newrelic/newrelic.jar"
  NEW_RELIC_DISTRIBUTED_TRACING_ENABLED: "true"
  NEW_RELIC_LABELS: "Environment:development;Team:arquitectura;Project:biblioteca"
```

**Variables clave:**
- **`NEW_RELIC_APP_NAME`**: Nombre de la app en New Relic Dashboard
- **`NEW_RELIC_LOG`**: Enviar logs a stdout (visible en kubectl logs)
- **`JAVA_TOOL_OPTIONS`**: Inyectar Java agent al iniciar la JVM
- **`NEW_RELIC_LABELS`**: Etiquetas para organizar en New Relic

---

### 2. biblioteca-secret.yaml (Actualizado)

Agregar License Key como Secret (⚠️ NO en ConfigMap):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: biblioteca-secret
type: Opaque
data:
  # Database Password
  SPRING_DATASOURCE_PASSWORD: cG9zdGdyZXM=
  
  # New Relic License Key (base64 encoded)
  NEW_RELIC_LICENSE_KEY: TlJBSy1BRFpZMDlSU0RFTjA2MDFCVUJLNkdRTUxOQlM=
```

**Codificar License Key:**
```bash
echo -n "NRAK-ADZY09RSDEN0601BUBK6GQMLNBS" | base64
# Resultado: TlJBSy1BRFpZMDlSU0RFTjA2MDFCVUJLNkdRTUxOQlM=
```

---

### 3. biblioteca-deployment.yaml (Actualizado)

Agregar initContainer, volume y volumeMounts:

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
      # --- NUEVO: Volumen para compartir agente ---
      volumes:
        - name: newrelic-agent
          emptyDir: {}
      
      # --- NUEVO: InitContainer para descargar agente ---
      initContainers:
        - name: download-newrelic-agent
          image: alpine:latest
          command:
            - sh
            - -c
            - |
              apk add --no-cache curl unzip && \
              echo "Descargando New Relic Java Agent..." && \
              curl -L https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip -o /tmp/newrelic-java.zip && \
              echo "Extrayendo agente..." && \
              unzip /tmp/newrelic-java.zip -d /mnt/newrelic && \
              echo "Agente instalado correctamente:" && \
              ls -la /mnt/newrelic/newrelic
          volumeMounts:
            - name: newrelic-agent
              mountPath: /mnt/newrelic
      
      # --- CONTENEDOR PRINCIPAL (actualizado) ---
      containers:
        - name: biblioteca-cqrs
          image: leounisabana/biblioteca-cqrs:1.0.2
          ports:
            - containerPort: 8089
          
          # Variables de entorno desde ConfigMap y Secret
          envFrom:
            - configMapRef:
                name: biblioteca-config
            - secretRef:
                name: biblioteca-secret
          
          # --- NUEVO: Montar volumen del agente ---
          volumeMounts:
            - name: newrelic-agent
              mountPath: /opt/newrelic
          
          # Health checks
          livenessProbe:
            httpGet:
              path: /actuator/health
              port: 8089
            initialDelaySeconds: 40  # Aumentado por overhead de New Relic
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: 8089
            initialDelaySeconds: 35  # Aumentado por overhead de New Relic
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          
          # Resources
          resources:
            requests:
              cpu: "250m"        # Aumentado por overhead de agent
              memory: "650Mi"    # Aumentado por overhead de agent
            limits:
              cpu: "500m"
              memory: "1Gi"
```

---

## 🔄 Flujo de Inicialización

### 1. Pod Creation
```
Kubernetes crea el Pod → Programado en nodo
```

### 2. Volume Creation
```
EmptyDir volume "newrelic-agent" creado en memoria/disco del nodo
```

### 3. InitContainer Execution
```
download-newrelic-agent inicia
    ↓
Instala curl y unzip
    ↓
Descarga newrelic-java.zip (~15MB)
    ↓
Extrae a /mnt/newrelic
    ↓
Lista archivos (verificación)
    ↓
InitContainer completa ✅
```

### 4. Main Container Starts
```
biblioteca-cqrs inicia
    ↓
Lee JAVA_TOOL_OPTIONS (contiene -javaagent:...)
    ↓
JVM carga /opt/newrelic/newrelic/newrelic.jar
    ↓
New Relic Agent se inicializa
    ↓
Lee NEW_RELIC_LICENSE_KEY
    ↓
Conecta a New Relic Platform
    ↓
Spring Boot inicia con instrumentación ✅
```

---

## 📊 ¿Qué Monitorea New Relic?

### Application Performance Monitoring (APM)

1. **Transactions & Throughput**
   - Requests por minuto
   - Response time promedio
   - Percentiles (p50, p95, p99)

2. **Database Queries**
   - Queries lentas
   - Tiempo de ejecución
   - N+1 queries

3. **External Services**
   - Llamadas HTTP externas
   - Latencia de APIs

4. **JVM Metrics**
   - Heap memory usage
   - Garbage collection
   - Thread pools

5. **Errors & Exceptions**
   - Stack traces
   - Error rate
   - Clasificación por tipo

6. **Distributed Tracing**
   - Request flow entre servicios
   - Identificar cuellos de botella

---

## 🖥️ Verificación

### 1. Verificar el InitContainer descargó el agente

```bash
# Ver logs del InitContainer
kubectl logs biblioteca-cqrs-<pod-id> -c download-newrelic-agent --context kind-biblioteca-cluster
```

Salida esperada:
```
Descargando New Relic Java Agent...
Extrayendo agente...
Agente instalado correctamente:
total 12K
drwxr-xr-x 3 root root 4.0K ...
-rw-r--r-- 1 root root  451 ... LICENSE
-rw-r--r-- 1 root root 7.5M ... newrelic.jar
...
```

### 2. Verificar New Relic Agent se cargó en la JVM

```bash
# Ver logs del contenedor principal
kubectl logs biblioteca-cqrs-<pod-id> --context kind-biblioteca-cluster | grep -i "new relic"
```

Salida esperada:
```
New Relic Agent v8.x.x has started
New Relic Agent: Successfully connected to New Relic collector
New Relic Agent: Reporting to https://rpm.newrelic.com/accounts/7785285/applications/...
```

### 3. Verificar variables de entorno

```bash
kubectl exec biblioteca-cqrs-<pod-id> --context kind-biblioteca-cluster -- env | grep NEW_RELIC
```

Salida:
```
NEW_RELIC_APP_NAME=biblioteca-cqrs
NEW_RELIC_LICENSE_KEY=NRAK-ADZY09RSDEN0601BUBK6GQMLNBS
NEW_RELIC_LOG=stdout
JAVA_TOOL_OPTIONS=-javaagent:/opt/newrelic/newrelic/newrelic.jar
```

### 4. Verificar archivo del agente

```bash
kubectl exec biblioteca-cqrs-<pod-id> --context kind-biblioteca-cluster -- ls -lh /opt/newrelic/newrelic/
```

---

## 🌐 Acceder al Dashboard de New Relic

### 1. Login
```
https://one.newrelic.com/
Email: yesidpera@unisabana.edu.co
```

### 2. Navegar a APM
```
APM & Services → biblioteca-cqrs
```

### 3. Dashboards Principales

- **Overview**: Health, throughput, response time
- **Transactions**: Endpoints más usados/lentos
- **Databases**: Queries y performance
- **External Services**: Llamadas a APIs externas
- **Errors**: Excepciones y stack traces
- **JVMs**: Heap, GC, threads
- **Distributed Tracing**: Request flow

---

## 🧪 Generar Tráfico para Monitoreo

```bash
# Port-forward
kubectl port-forward service/biblioteca-service 8089:8089 --context kind-biblioteca-cluster &

# Generar requests
for i in {1..100}; do
  curl -X POST http://localhost:8089/libros \
    -H 'Content-Type: application/json' \
    -d "{\"id\":\"lib-$i\",\"titulo\":\"Libro $i\"}"
  
  curl http://localhost:8089/libros/lib-$i
  
  sleep 0.5
done
```

En New Relic verás:
- 100 POST requests a `/libros`
- 100 GET requests a `/libros/{id}`
- Database queries (INSERT y SELECT)
- Response times
- Throughput

---

## 📈 Métricas Clave a Monitorear

### Performance
- **Response Time**: < 200ms (excelente), < 500ms (aceptable)
- **Throughput**: Requests/minuto según carga esperada
- **Error Rate**: < 1% (idealmente < 0.1%)

### Resources
- **Heap Memory**: < 80% del límite
- **GC Pause Time**: < 100ms
- **CPU Usage**: < 70% promedio

### Database
- **Query Time**: < 50ms promedio
- **Slow Queries**: Identificar > 100ms
- **Connection Pool**: Uso < 80%

---

## ⚠️ Consideraciones

### InitContainer Overhead

- Añade ~10-15 segundos al startup del Pod
- Descarga ~15MB cada vez que se crea un Pod
- En producción, considerar:
  - Imagen custom con agente pre-instalado
  - Cache del agente en un volume persistente

### Imagen Custom (Alternativa)

**Dockerfile:**
```dockerfile
FROM leounisabana/biblioteca-cqrs:1.0.2

# Descargar New Relic Agent durante build
RUN apt-get update && apt-get install -y curl unzip && \
    curl -L https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip -o /tmp/newrelic-java.zip && \
    unzip /tmp/newrelic-java.zip -d /opt && \
    rm /tmp/newrelic-java.zip && \
    apt-get remove -y curl unzip && \
    apt-get clean

ENV JAVA_TOOL_OPTIONS="-javaagent:/opt/newrelic/newrelic.jar"
```

**Build y push:**
```bash
docker build -t leounisabana/biblioteca-cqrs:1.0.2-newrelic .
docker push leounisabana/biblioteca-cqrs:1.0.2-newrelic
```

**Deployment:**
```yaml
containers:
  - name: biblioteca-cqrs
    image: leounisabana/biblioteca-cqrs:1.0.2-newrelic
    # No necesita initContainer ni volumeMounts
```

### Recursos Adicionales

New Relic agent agrega overhead:
- **CPU**: +10-20%
- **Memory**: +100-150MB

Por eso aumentamos los `requests` en el deployment.

---

## 🎓 Conceptos Clave

- **APM**: Application Performance Monitoring
- **Java Agent**: Instrumentación bytecode para monitoreo
- **InitContainer**: Container que se ejecuta antes del principal
- **EmptyDir Volume**: Volumen temporal compartido entre containers
- **Distributed Tracing**: Seguimiento de requests entre servicios
- **Observability**: Entender el estado del sistema mediante métricas, logs y trazas

---

## 🔗 Referencias

- [New Relic Java Agent](https://docs.newrelic.com/docs/apm/agents/java-agent/getting-started/introduction-new-relic-java/)
- [Java Agent Configuration](https://docs.newrelic.com/docs/apm/agents/java-agent/configuration/java-agent-configuration-config-file/)
- [New Relic Kubernetes Integration](https://docs.newrelic.com/docs/kubernetes-pixie/kubernetes-integration/get-started/introduction-kubernetes-integration/)

---

## ✅ Checklist de Integración

- [ ] Actualizar `biblioteca-configmap.yaml` con variables de New Relic
- [ ] Actualizar `biblioteca-secret.yaml` con License Key
- [ ] Actualizar `biblioteca-deployment.yaml` con initContainer y volumes
- [ ] Aplicar manifiestos actualizados
- [ ] Verificar InitContainer completó exitosamente
- [ ] Verificar agent se cargó en logs
- [ ] Generar tráfico de prueba
- [ ] Acceder a New Relic Dashboard
- [ ] Verificar métricas aparecen en APM
- [ ] Configurar alertas en New Relic (opcional)
