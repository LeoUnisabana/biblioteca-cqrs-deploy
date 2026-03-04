# Service - biblioteca-service

## 📄 Archivo: `k8s/biblioteca-service.yaml`

## ¿Qué es un Service?

Un **Service** es un objeto de Kubernetes que proporciona una abstracción para acceder a un conjunto de Pods. Actúa como un load balancer interno, proporcionando una IP y DNS estables, aunque los Pods subyacentes cambien.

## Contenido del Archivo

```yaml
apiVersion: v1
kind: Service
metadata:
  name: biblioteca-service
spec:
  selector:
    app: biblioteca-cqrs
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 8089
      targetPort: 8089
```

---

## 📋 Explicación Línea por Línea

### Metadatos API

```yaml
apiVersion: v1
```
- **`apiVersion: v1`**: API core de Kubernetes
- Services están en la API estable desde el principio

```yaml
kind: Service
```
- **`kind`**: Tipo de recurso
- **`Service`**: Objeto de red para acceder a Pods

---

### Metadatos del Service

```yaml
metadata:
  name: biblioteca-service
```
- **`name`**: Nombre único del Service en el namespace
- **`biblioteca-service`**: Se usa como DNS name dentro del cluster

**DNS Interno:**
```
biblioteca-service              # En el mismo namespace
biblioteca-service.default      # Namespace específico
biblioteca-service.default.svc.cluster.local  # FQDN completo
```

---

### Especificación del Service

```yaml
spec:
  selector:
    app: biblioteca-cqrs
```
- **`selector`**: Define qué Pods son parte de este Service
- **`app: biblioteca-cqrs`**: Selecciona Pods con esta etiqueta
- **Importante:** Debe coincidir con las labels de los Pods en el Deployment

**Funcionamiento:**
El Service busca todos los Pods con `app: biblioteca-cqrs` y los agrega a su pool de endpoints. Si hay múltiples réplicas, el Service balancea el tráfico entre ellas.

```yaml
  type: ClusterIP
```
- **`type`**: Tipo de Service
- **`ClusterIP`**: IP interna del cluster (no accesible desde fuera)

**Tipos de Service:**
1. **ClusterIP** (default): Solo accesible dentro del cluster
2. **NodePort**: Expone en un puerto de cada nodo
3. **LoadBalancer**: Crea un load balancer externo (cloud providers)
4. **ExternalName**: Mapea a un DNS externo

---

### Configuración de Puertos

```yaml
  ports:
    - protocol: TCP
```
- **`ports`**: Lista de puertos que el Service expone
- **`protocol: TCP`**: Protocolo de red (TCP o UDP)

```yaml
      port: 8089
```
- **`port`**: Puerto en el que el Service escucha
- **8089**: Puerto al que se conectan otros servicios/pods
- Este es el puerto que se usa en las URLs: `http://biblioteca-service:8089`

```yaml
      targetPort: 8089
```
- **`targetPort`**: Puerto del contenedor al que se reenvía el tráfico
- **8089**: Puerto en el que escucha la aplicación Spring Boot
- Debe coincidir con `containerPort` en el Deployment

**Flujo de tráfico:**
```
Cliente interno → biblioteca-service:8089 → Pod:8089 → Contenedor:8089
```

---

## 🌐 Cómo Funciona un Service

### 1. Service Discovery

Cuando creas un Service, Kubernetes automáticamente:

#### DNS
```bash
# Desde cualquier Pod en el cluster:
curl http://biblioteca-service:8089/actuator/health
```

#### Variables de Entorno
```bash
BIBLIOTECA_SERVICE_SERVICE_HOST=10.96.229.46
BIBLIOTECA_SERVICE_SERVICE_PORT=8089
```

### 2. Load Balancing

Si tienes múltiples réplicas:
```yaml
# Deployment con 3 réplicas
spec:
  replicas: 3
```

El Service balancea el tráfico entre los 3 Pods automáticamente:
```
biblioteca-service:8089
    ├─> Pod-1 (10.244.0.8:8089)
    ├─> Pod-2 (10.244.0.9:8089)
    └─> Pod-3 (10.244.0.10:8089)
```

### 3. Endpoints

Kubernetes mantiene una lista de endpoints (IPs de Pods):

```bash
kubectl get endpoints biblioteca-service --context kind-biblioteca-cluster
```

Salida:
```
NAME                 ENDPOINTS         AGE
biblioteca-service   10.244.0.8:8089   2h
```

---

## 🔄 Interacción con Otros Recursos

### Conexión desde PostgreSQL (simulación)

Si otro Pod quiere conectarse a biblioteca-cqrs:

```yaml
# En otro deployment
env:
  - name: API_URL
    value: "http://biblioteca-service:8089"
```

### Usado por ConfigMap

```yaml
# En biblioteca-configmap.yaml
# PostgreSQL se conecta desde biblioteca-cqrs usando:
SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-service:5432/library
                                         ↑
                                    Service DNS
```

---

## 🔧 Comandos Útiles

### Aplicar el Service
```bash
kubectl apply -f k8s/biblioteca-service.yaml --context kind-biblioteca-cluster
```

### Ver Services
```bash
kubectl get services --context kind-biblioteca-cluster
# o abreviado:
kubectl get svc --context kind-biblioteca-cluster
```

Salida:
```
NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
biblioteca-service   ClusterIP   10.96.229.46   <none>        8089/TCP   3h
```

### Describir Service
```bash
kubectl describe service biblioteca-service --context kind-biblioteca-cluster
```

### Ver Endpoints del Service
```bash
kubectl get endpoints biblioteca-service --context kind-biblioteca-cluster
```

### Probar Service desde dentro del cluster
```bash
# Crear un pod temporal con curl
kubectl run -it --rm debug --image=curlimages/curl --restart=Never --context kind-biblioteca-cluster -- curl http://biblioteca-service:8089/actuator/health
```

### Port-forward para acceso local
```bash
kubectl port-forward service/biblioteca-service 8089:8089 --context kind-biblioteca-cluster
```
Luego acceder desde tu máquina: `http://localhost:8089`

### Eliminar Service
```bash
kubectl delete service biblioteca-service --context kind-biblioteca-cluster
```

---

## 🔀 Tipos de Service Detallados

### ClusterIP (Actual)

**Características:**
- IP interna del cluster
- No accesible desde fuera
- DNS automático

**Usar cuando:**
- Comunicación entre servicios internos
- Desarrollo local con port-forward
- Backend no expuesto públicamente

```yaml
type: ClusterIP
ports:
  - port: 8089
    targetPort: 8089
```

### NodePort

**Características:**
- Asigna un puerto en cada nodo (30000-32767)
- Accesible desde: `<NodeIP>:<NodePort>`

**Ejemplo:**
```yaml
type: NodePort
ports:
  - port: 8089
    targetPort: 8089
    nodePort: 30080  # Opcional, si no se especifica, Kubernetes asigna uno
```

**Acceso:**
```bash
curl http://<node-ip>:30080/actuator/health
```

### LoadBalancer

**Características:**
- Crea un load balancer externo (AWS ELB, GCP LB, Azure LB)
- Asigna una IP pública
- Solo funciona en cloud providers

**Ejemplo:**
```yaml
type: LoadBalancer
ports:
  - port: 8089
    targetPort: 8089
```

### ExternalName

**Características:**
- Mapea a un DNS externo
- No usa selectors ni endpoints

**Ejemplo:**
```yaml
type: ExternalName
externalName: external-api.example.com
```

---

## 📊 Diferencia entre Port y TargetPort

### Ejemplo 1: Puertos Iguales (Actual)

```yaml
ports:
  - port: 8089        # Service escucha en 8089
    targetPort: 8089  # Pod escucha en 8089
```

**Acceso:**
```bash
curl http://biblioteca-service:8089/actuator/health
```

**Flujo:**
```
Cliente:8089 → Service:8089 → Pod:8089
```

### Ejemplo 2: Puertos Diferentes

```yaml
ports:
  - port: 80          # Service escucha en 80
    targetPort: 8089  # Pod escucha en 8089
```

**Acceso:**
```bash
curl http://biblioteca-service:80/actuator/health
# Internamente se reenvía al pod en el puerto 8089
```

**Flujo:**
```
Cliente:80 → Service:80 → Pod:8089
```

**Ventaja:** Permite exponer servicios en puertos estándar (80, 443) aunque la aplicación use otros puertos.

---

## 🎯 Session Affinity

Por defecto, el Service balancea aleatoriamente. Para sticky sessions:

```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
```

**Uso:** Mantener al mismo cliente conectado al mismo Pod.

---

## 🔗 Headless Service

Para acceder directamente a Pods individuales sin load balancing:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: biblioteca-headless
spec:
  selector:
    app: biblioteca-cqrs
  clusterIP: None  # Headless
  ports:
    - port: 8089
      targetPort: 8089
```

**DNS resuelve a IPs de todos los Pods:**
```bash
nslookup biblioteca-headless
# Respuesta: 10.244.0.8, 10.244.0.9, 10.244.0.10
```

**Usar para:** StatefulSets, bases de datos distribuidas, Kafka, etc.

---

## ⚠️ Consideraciones Importantes

### Selector debe coincidir con Pods
```yaml
# Service
selector:
  app: biblioteca-cqrs

# Deployment
template:
  metadata:
    labels:
      app: biblioteca-cqrs  # ✅ Debe coincidir
```

### Service sin Endpoints
Si no hay Pods con las etiquetas correctas:
```bash
kubectl get endpoints biblioteca-service
# NAME                 ENDPOINTS   AGE
# biblioteca-service   <none>      10s
```

**Causas comunes:**
- Labels no coinciden
- Pods no están en estado Ready
- readinessProbe falla

### Puertos vs Ports
```yaml
# En Deployment
ports:
  - containerPort: 8089  # Documenta el puerto, no lo abre

# En Service
ports:
  - port: 8089           # Puerto del Service
    targetPort: 8089     # Puerto del Contenedor
```

---

## 🔗 Referencias en Otros Archivos

Este Service es usado por:
- **Port-forward**: Para acceso desde localhost
- **Ingress** (futuro): Para exposición externa
- **Otros Pods**: Para comunicación interna

Este Service selecciona Pods de:
- **`biblioteca-deployment.yaml`**: Pods con label `app: biblioteca-cqrs`

---

## 📝 Ejemplo de Service Expandido

Con múltiples puertos y configuración avanzada:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: biblioteca-service
  labels:
    app: biblioteca-cqrs
  annotations:
    service.kubernetes.io/topology-aware-hints: "auto"
spec:
  selector:
    app: biblioteca-cqrs
  type: ClusterIP
  ports:
    - name: http
      protocol: TCP
      port: 8089
      targetPort: 8089
    - name: metrics
      protocol: TCP
      port: 9090
      targetPort: 9090
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
```

---

## 🎓 Conceptos Clave

- **Service Discovery**: DNS interno para encontrar servicios
- **Load Balancing**: Distribuye tráfico entre Pods
- **Stable Endpoint**: IP y DNS estables aunque Pods cambien
- **Selector**: Vincular Service con Pods mediante labels
- **Port Mapping**: port (Service) → targetPort (Pod)
- **Types**: ClusterIP, NodePort, LoadBalancer, ExternalName

---

## 🔍 Troubleshooting

### Service no responde

```bash
# 1. Verificar Service existe
kubectl get service biblioteca-service --context kind-biblioteca-cluster

# 2. Verificar Endpoints
kubectl get endpoints biblioteca-service --context kind-biblioteca-cluster

# 3. Si no hay endpoints, verificar Pods
kubectl get pods -l app=biblioteca-cqrs --context kind-biblioteca-cluster

# 4. Verificar labels de Pods
kubectl get pods --show-labels --context kind-biblioteca-cluster

# 5. Verificar readinessProbe
kubectl describe pod <pod-name> --context kind-biblioteca-cluster
```

### Conexión rechazada

- Verificar `targetPort` coincide con `containerPort`
- Verificar aplicación escucha en todas las interfaces (0.0.0.0, no solo localhost)
- Verificar readinessProbe pasa

### DNS no resuelve

```bash
# Desde un Pod:
nslookup biblioteca-service
nslookup biblioteca-service.default.svc.cluster.local

# Verificar CoreDNS
kubectl get pods -n kube-system | grep coredns
```
