# PostgreSQL - Deployment, Service y PVC

## 📄 Archivos Base de Datos

Los manifiestos de PostgreSQL proveen una base de datos completamente funcional dentro del cluster de Kubernetes con almacenamiento persistente.

---

## 1. postgres-pvc.yaml - PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

### ¿Qué es un PVC?

Un **PersistentVolumeClaim** (PVC) es una solicitud de almacenamiento. Kubernetes encontrará un **PersistentVolume** (PV) disponible o creará uno dinámicamente.

### Explicación

- **`storageClassName: standard`**: Clase de almacenamiento
  - En **kind**: Usa volúmenes locales del nodo
  - En **cloud**: Usa discos del proveedor (EBS, Azure Disk, etc.)

- **`accessModes: - ReadWriteOnce`**: Modo de acceso
  - **ReadWriteOnce (RWO)**: Un solo nodo puede montar lectura/escritura
  - **ReadOnlyMany (ROX)**: Múltiples nodos solo lectura
  - **ReadWriteMany (RWX)**: Múltiples nodos lectura/escritura

- **`storage: 1Gi`**: Tamaño solicitado (1 Gibibyte)

### ¿Por qué se usa?

Sin PVC, los datos de PostgreSQL se perderían si el Pod se reinicia. Con PVC:
- ✅ Datos persisten entre reinicios
- ✅ Datos persisten si el Pod se mueve a otro nodo
- ✅ Datos independientes del ciclo de vida del Pod

### Comandos

```bash
# Aplicar
kubectl apply -f k8s/postgres-pvc.yaml --context kind-biblioteca-cluster

# Ver PVCs
kubectl get pvc --context kind-biblioteca-cluster

# Ver detalles
kubectl describe pvc postgres-pvc --context kind-biblioteca-cluster

# Ver PV automáticamente creado
kubectl get pv --context kind-biblioteca-cluster
```

---

## 2. postgres-deployment.yaml - Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_DB
              value: library
            - name: POSTGRES_USER
              value: postgres
            - name: POSTGRES_PASSWORD
              value: postgres
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: postgres-storage
          persistentVolumeClaim:
            claimName: postgres-pvc
```

### Componentes Clave

#### Imagen
```yaml
image: postgres:16-alpine
```
- **postgres:16**: PostgreSQL versión 16
- **alpine**: Versión ligera basada en Alpine Linux (~80MB vs ~300MB)

#### Variables de Entorno
```yaml
env:
  - name: POSTGRES_DB
    value: library
```
- **POSTGRES_DB**: Nombre de la base de datos a crear
- **POSTGRES_USER**: Usuario superadmin
- **POSTGRES_PASSWORD**: Contraseña (⚠️ en texto plano, debería estar en Secret)

#### Volumen
```yaml
volumeMounts:
  - name: postgres-storage
    mountPath: /var/lib/postgresql/data
```
- **`mountPath`**: Directorio donde PostgreSQL guarda datos
- Conectado al PVC `postgres-pvc`

```yaml
volumes:
  - name: postgres-storage
    persistentVolumeClaim:
      claimName: postgres-pvc
```
- **`claimName`**: Referencia al PVC creado anteriormente

**Flujo de datos:**
```
PostgreSQL escribe → /var/lib/postgresql/data → Volume → PVC → PV (disco)
```

### Réplicas

```yaml
replicas: 1
```

⚠️ **Importante:** PostgreSQL no se puede escalar horizontalmente fácilmente:
- Solo **1 réplica** para escritura
- Para HA (Alta Disponibilidad), usar:
  - **StatefulSet** (no Deployment)
  - **Operadores** (como Crunchy, Zalando, CloudNativePG)
  - **Replication** (Primary-Replica setup)

### Comandos

```bash
# Aplicar
kubectl apply -f k8s/postgres-deployment.yaml --context kind-biblioteca-cluster

# Ver Pods
kubectl get pods -l app=postgres --context kind-biblioteca-cluster

# Logs
kubectl logs -l app=postgres --context kind-biblioteca-cluster --tail=50

# Conectarse a PostgreSQL
kubectl exec -it <postgres-pod-name> --context kind-biblioteca-cluster -- psql -U postgres -d library

# Dentro de psql:
\dt                          # Listar tablas
SELECT * FROM libro;         # Ver libros
\q                           # Salir
```

---

## 3. postgres-service.yaml - Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
  type: ClusterIP
```

### Propósito

Proporciona un DNS estable para acceder a PostgreSQL:
```
postgres-service:5432
```

Usado en `biblioteca-configmap.yaml`:
```yaml
SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-service:5432/library
                                         ↑ Service DNS
```

### Puerto
```yaml
- port: 5432
  targetPort: 5432
```
- **5432**: Puerto estándar de PostgreSQL
- Tanto el Service como el contenedor usan el mismo puerto

### ClusterIP

```yaml
type: ClusterIP
```
- Solo accesible dentro del cluster
- No expuesto externamente (seguridad)

### Comandos

```bash
# Aplicar
kubectl apply -f k8s/postgres-service.yaml --context kind-biblioteca-cluster

# Ver Service
kubectl get svc postgres-service --context kind-biblioteca-cluster

# Ver Endpoints
kubectl get endpoints postgres-service --context kind-biblioteca-cluster

# Probar conexión desde otro Pod
kubectl run -it --rm psql-client --image=postgres:16-alpine --restart=Never --context kind-biblioteca-cluster -- psql -h postgres-service -U postgres -d library
```

---

## 🔄 Orden de Aplicación

**Orden correcto:**

1. **PVC primero** (se necesita antes del Deployment)
   ```bash
   kubectl apply -f k8s/postgres-pvc.yaml --context kind-biblioteca-cluster
   ```

2. **Deployment** (monta el PVC)
   ```bash
   kubectl apply -f k8s/postgres-deployment.yaml --context kind-biblioteca-cluster
   ```

3. **Service** (expone el Deployment)
   ```bash
   kubectl apply -f k8s/postgres-service.yaml --context kind-biblioteca-cluster
   ```

**O todos juntos:**
```bash
kubectl apply -f k8s/postgres-pvc.yaml -f k8s/postgres-deployment.yaml -f k8s/postgres-service.yaml --context kind-biblioteca-cluster
```

---

## 🔍 Verificación

### 1. Verificar PVC está Bound
```bash
kubectl get pvc postgres-pvc --context kind-biblioteca-cluster
```
Salida esperada:
```
NAME           STATUS   VOLUME                 CAPACITY   ACCESS MODES
postgres-pvc   Bound    pvc-a1b2c3d4-...       1Gi        RWO
```

### 2. Verificar Pod está Running
```bash
kubectl get pods -l app=postgres --context kind-biblioteca-cluster
```
Salida esperada:
```
NAME                       READY   STATUS    RESTARTS   AGE
postgres-fdf79fc69-xxxxx   1/1     Running   0          2m
```

### 3. Ver logs de PostgreSQL
```bash
kubectl logs -l app=postgres --context kind-biblioteca-cluster --tail=20
```
Buscar:
```
PostgreSQL init process complete; ready for start up.
database system is ready to accept connections
```

### 4. Probar conexión desde Spring Boot
```bash
# Ver logs de biblioteca-cqrs
kubectl logs -l app=biblioteca-cqrs --context kind-biblioteca-cluster

# Buscar:
# HikariPool-1 - Start completed
# Database is up to date, no changesets to execute
```

---

## 🗄️ Gestión de Datos

### Backup Manual

```bash
# Exportar base de datos
kubectl exec <postgres-pod> --context kind-biblioteca-cluster -- pg_dump -U postgres library > backup.sql

# Importar base de datos
kubectl exec -i <postgres-pod> --context kind-biblioteca-cluster -- psql -U postgres library < backup.sql
```

### Ver datos del volumen

```bash
# En kind, los volúmenes están en el nodo
docker exec -it biblioteca-cluster-control-plane ls -la /var/local-path-provisioner/
```

### Limpiar datos (eliminar y recrear)

```bash
# Eliminar Deployment y Service
kubectl delete -f k8s/postgres-deployment.yaml --context kind-biblioteca-cluster
kubectl delete -f k8s/postgres-service.yaml --context kind-biblioteca-cluster

# Eliminar PVC (esto BORRA LOS DATOS)
kubectl delete -f k8s/postgres-pvc.yaml --context kind-biblioteca-cluster

# Recrear todo
kubectl apply -f k8s/postgres-pvc.yaml -f k8s/postgres-deployment.yaml -f k8s/postgres-service.yaml --context kind-biblioteca-cluster
```

---

## ⚠️ Consideraciones de Seguridad

### Contraseña en Texto Plano

❌ **Problema:**
```yaml
env:
  - name: POSTGRES_PASSWORD
    value: postgres  # ← Texto plano en el manifiesto
```

✅ **Solución:**
```yaml
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretRef:
        name: postgres-secret
        key: POSTGRES_PASSWORD
```

Crear Secret:
```bash
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_PASSWORD=postgres \
  --context kind-biblioteca-cluster
```

### Acceso Externo

**Por defecto:** ClusterIP (solo interno) ✅

**Si necesitas acceso externo:**
```yaml
type: NodePort  # Para desarrollo
# o
type: LoadBalancer  # Para cloud con firewall
```

⚠️ **Producción:** NUNCA exponer PostgreSQL directamente. Usar:
- VPN
- Bastion hosts
- Cloud private endpoints

---

## 🎯 PostgreSQL vs Ejemplo

### Ejemplo (miprimeraapi)
- Base de datos **externa** (IP: 67.217.56.24)
- No gestionada por Kubernetes
- Sin PVC ni volúmenes

### Biblioteca CQRS
- Base de datos **dentro del cluster**
- Gestionada por Kubernetes
- Con volumenes persistentes (PVC)

**Ventajas de nuestro approach:**
- ✅ Autocontenido (no depende de servicios externos)
- ✅ Portátil (funciona en cualquier cluster)
- ✅ Datos persistentes
- ✅ Fácil para desarrollo/demo

**Desventajas:**
- ⚠️ No optimizado para producción
- ⚠️ No tiene HA automática
- ⚠️ Backups manuales

---

## 🚀 Alternativas para Producción

1. **Operadores de Kubernetes**
   - Crunchy PostgreSQL Operator
   - Zalando PostgreSQL Operator
   - CloudNativePG

2. **Servicios Gestionados (Cloud)**
   - AWS RDS for PostgreSQL
   - Azure Database for PostgreSQL
   - Google Cloud SQL for PostgreSQL

3. **StatefulSet (en lugar de Deployment)**
   - Para réplicas con identidad estable
   - Mejor para bases de datos distribuidas

---

## 🔗 Referencias

Estos manifiestos son usados por:
- **`biblioteca-configmap.yaml`**: URL de conexión apunta a `postgres-service`
- **`biblioteca-secret.yaml`**: Password debe coincidir con `POSTGRES_PASSWORD`
- **`biblioteca-deployment.yaml`**: Se conecta a PostgreSQL para persistencia

---

## 🎓 Conceptos Clave

- **PVC**: Solicitud de almacenamiento persistente
- **PV**: Volumen físico de almacenamiento
- **StorageClass**: Cómo se provisiona el almacenamiento
- **VolumeMount**: Conecta el volumen al contenedor
- **StatefulSet**: Mejor que Deployment para bases de datos (pero más complejo)
