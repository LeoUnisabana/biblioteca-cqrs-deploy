# Ingress - Exposición Externa con NGINX

## 📄 Archivo: `k8s/biblioteca-ingress.yaml` (⚠️ NO IMPLEMENTADO AÚN)

## ¿Qué es un Ingress?

Un **Ingress** es un objeto de Kubernetes que gestiona el acceso externo a los servicios del cluster, típicamente HTTP/HTTPS. Proporciona load balancing, terminación SSL y routing basado en nombre.

## ¿Por qué lo necesitamos?

Actualmente usamos `kubectl port-forward` para acceder a la aplicación:
```bash
kubectl port-forward service/biblioteca-service 8089:8089
```

**Limitaciones:**
- ❌ Manual (requiere comando corriendo)
- ❌ Solo una conexión a la vez
- ❌ No escalable
- ❌ Sin SSL/TLS
- ❌ No productivo

**Con Ingress:**
- ✅ Acceso mediante URL (ej: `http://biblioteca.local`)
- ✅ Múltiples conexiones
- ✅ Load balancing automático
- ✅ SSL/TLS support
- ✅ Path routing (múltiples servicios en una URL)

---

## 🔧 Prerequisitos

### 1. Ingress Controller

Un Ingress requiere un **Ingress Controller** (no viene por defecto en Kubernetes):

**Opciones populares:**
- **NGINX Ingress Controller** (más común)
- Traefik
- HAProxy
- Kong
- AWS ALB Ingress Controller
- GCE Ingress Controller

### Instalar NGINX Ingress en kind:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml --context kind-biblioteca-cluster

# Esperar a que esté ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s \
  --context kind-biblioteca-cluster
```

### Verificar instalación:

```bash
kubectl get pods -n ingress-nginx --context kind-biblioteca-cluster
kubectl get svc -n ingress-nginx --context kind-biblioteca-cluster
```

---

## 📄 Manifesto Propuesto

### biblioteca-ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: biblioteca-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: biblioteca.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: biblioteca-service
            port:
              number: 8089
```

---

## 📋 Explicación Línea por Línea

### Metadatos y Anotaciones

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: biblioteca-ingress
```

```yaml
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
```
- **`rewrite-target`**: Reescribe el path antes de enviar al backend
- **Ejemplo:** Request a `/api/libros` → Reescribe a `/libros`

```yaml
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
```
- **`ssl-redirect`**: No redirigir HTTP a HTTPS automáticamente
- Útil para desarrollo (sin certificados)

**Otras anotaciones útiles:**
```yaml
annotations:
  nginx.ingress.kubernetes.io/cors-enable: "true"
  nginx.ingress.kubernetes.io/rate-limit: "100"
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

### Especificación

```yaml
spec:
  ingressClassName: nginx
```
- **`ingressClassName`**: Qué Ingress Controller usar
- **nginx**: NGINX Ingress Controller

```yaml
  rules:
  - host: biblioteca.local
```
- **`host`**: Hostname para routing
- **biblioteca.local**: DNS local (configurar en `/etc/hosts` o similar)

```yaml
    http:
      paths:
      - path: /
        pathType: Prefix
```
- **`path: /`**: Ruta base (todas las peticiones)
- **`pathType: Prefix`**: Coincide con paths que empiecen con `/`

**Tipos de pathType:**
- **Prefix**: `/api` coincide con `/api/*`
- **Exact**: Solo `/api` (no `/api/libros`)
- **ImplementationSpecific**: Depende del Ingress Controller

```yaml
        backend:
          service:
            name: biblioteca-service
            port:
              number: 8089
```
- **`backend`**: A dónde enviar el tráfico
- **`service`**: Service de Kubernetes
- **`port: 8089`**: Puerto del Service

---

## 🌐 Configuración del Host

### Opción 1: Editar /etc/hosts (Linux/Mac)

```bash
sudo nano /etc/hosts
```

Agregar:
```
127.0.0.1  biblioteca.local
```

### Opción 2: Editar hosts en Windows

```powershell
# Ejecutar como Administrador
notepad C:\Windows\System32\drivers\etc\hosts
```

Agregar:
```
127.0.0.1  biblioteca.local
```

### Opción 3: Usar nip.io (DNS wildcard)

En lugar de `biblioteca.local`, usar:
```yaml
- host: biblioteca.127.0.0.1.nip.io
```

No requiere configuración de DNS.

---

## 🚀 Aplicar y Probar

### 1. Aplicar el Ingress

```bash
kubectl apply -f k8s/biblioteca-ingress.yaml --context kind-biblioteca-cluster
```

### 2. Verificar Ingress

```bash
kubectl get ingress --context kind-biblioteca-cluster
```

Salida:
```
NAME                 CLASS   HOSTS              ADDRESS     PORTS   AGE
biblioteca-ingress   nginx   biblioteca.local   localhost   80      30s
```

### 3. Describir Ingress

```bash
kubectl describe ingress biblioteca-ingress --context kind-biblioteca-cluster
```

### 4. Probar Acceso

```bash
# Desde navegador o curl
curl http://biblioteca.local/actuator/health

# Swagger UI
open http://biblioteca.local/swagger-ui.html
```

---

## 🔀 Path Routing Avanzado

Para múltiples servicios:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: biblioteca-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: biblioteca.local
    http:
      paths:
      # API de biblioteca
      - path: /api(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: biblioteca-service
            port:
              number: 8089
      
      # Otro servicio (futuro)
      - path: /admin(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: admin-service
            port:
              number: 8090
```

**Acceso:**
- `http://biblioteca.local/api/libros` → biblioteca-service
- `http://biblioteca.local/admin/users` → admin-service

---

## 🔐 SSL/TLS con cert-manager

### 1. Instalar cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml --context kind-biblioteca-cluster
```

### 2. Crear ClusterIssuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: yesidpera@unisabana.edu.co
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

### 3. Actualizar Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: biblioteca-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - biblioteca.example.com
    secretName: biblioteca-tls
  rules:
  - host: biblioteca.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: biblioteca-service
            port:
              number: 8089
```

**cert-manager** generará automáticamente un certificado SSL válido.

---

## 🎯 Comparativa con Ejemplo

### Ejemplo (miprimeraapi)

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

**Diferencias:**
- **Ejemplo**: Path `/lavaca` (sub-path)
- **Biblioteca**: Path `/` (root)
- **Ejemplo**: Puerto 9090
- **Biblioteca**: Puerto 8089
- **Ejemplo**: Sin hostname específico (cualquier host)
- **Biblioteca**: Hostname `biblioteca.local`

**Acceso:**
- Ejemplo: `http://<cluster-ip>/lavaca/users`
- Biblioteca: `http://biblioteca.local/libros`

---

## 🔧 Troubleshooting

### Ingress no tiene ADDRESS

```bash
kubectl get ingress --context kind-biblioteca-cluster
# NAME                 CLASS   HOSTS              ADDRESS   PORTS   AGE
# biblioteca-ingress   nginx   biblioteca.local             80      5m
```

**Causas:**
- Ingress Controller no instalado
- Ingress Controller no ready

**Solución:**
```bash
kubectl get pods -n ingress-nginx --context kind-biblioteca-cluster
# Verificar que todos los pods estén Running
```

### 503 Service Unavailable

**Causas:**
- Service no existe
- Service sin endpoints (Pods no ready)
- Labels no coinciden

**Solución:**
```bash
kubectl get svc biblioteca-service --context kind-biblioteca-cluster
kubectl get endpoints biblioteca-service --context kind-biblioteca-cluster
kubectl get pods -l app=biblioteca-cqrs --context kind-biblioteca-cluster
```

### 404 Not Found

**Causas:**
- Path incorrecto
- Rewrite-target mal configurado
- Application no tiene ese endpoint

**Solución:**
```bash
# Ver logs del Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50 --context kind-biblioteca-cluster

# Probar directamente al Service
kubectl port-forward service/biblioteca-service 8089:8089 --context kind-biblioteca-cluster
curl http://localhost:8089/actuator/health
```

---

## 📊 Ventajas de usar Ingress

| Sin Ingress (Port-forward) | Con Ingress |
|----------------------------|-------------|
| Manual | Automático |
| Una conexión | Múltiples conexiones |
| `localhost:8089` | `biblioteca.local` |
| Sin SSL | SSL/TLS support |
| Un servicio a la vez | Múltiples servicios |
| No productivo | Production-ready |
| Sin load balancing | Load balancing |
| Sin rate limiting | Rate limiting configurable |

---

## 🎓 Conceptos Clave

- **Ingress**: Routing de tráfico HTTP/HTTPS
- **Ingress Controller**: Implementación del Ingress (NGINX, Traefik, etc.)
- **Path Routing**: Enrutar según el path URL
- **Host Routing**: Enrutar según el hostname
- **TLS Termination**: Manejar SSL/TLS en el Ingress
- **Annotations**: Configuración específica del controller

---

## ✅ Próximos Pasos

1. **Instalar NGINX Ingress Controller en el cluster**
2. **Crear el manifiesto `biblioteca-ingress.yaml`**
3. **Configurar DNS local** (`/etc/hosts`)
4. **Aplicar y probar** el Ingress
5. **(Opcional) Configurar SSL** con cert-manager
6. **Eliminar port-forward** (ya no necesario)

---

## 🔗 Referencias

- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Kubernetes Ingress Docs](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [cert-manager](https://cert-manager.io/)
- [Let's Encrypt](https://letsencrypt.org/)
