# Helm Chart - Biblioteca CQRS

## 🚀 Inicio Rápido

### 1. Instalación Básica (Script Automático)

```powershell
# Instalar con valores por defecto
.\install-helm-chart.ps1

# Instalar ambiente de desarrollo
.\install-helm-chart.ps1 -Environment dev -Namespace dev -CreateNamespace

# Instalar ambiente de producción
.\install-helm-chart.ps1 -Environment prod -Namespace prod -CreateNamespace

# Dry-run (ver qué va a hacer sin ejecutar)
.\install-helm-chart.ps1 -Environment dev -DryRun

# Upgrade de un release existente
.\install-helm-chart.ps1 -Environment prod -Upgrade -ReleaseName biblioteca-prod
```

### 2. Instalación Manual con Helm

```bash
# Instalar Helm (si no lo tienes)
wsl bash -c 'curl -LO https://get.helm.sh/helm-v3.20.0-linux-amd64.tar.gz && tar -zxvf helm-v3.20.0-linux-amd64.tar.gz && mkdir -p ~/bin && mv linux-amd64/helm ~/bin/ && chmod +x ~/bin/helm'

# Agregar ~/bin al PATH de WSL (agregar a ~/.bashrc)
echo 'export PATH=$PATH:~/bin' >> ~/.bashrc

# Instalar el chart
cd helm/biblioteca-chart
wsl ~/bin/helm install biblioteca . --namespace default

# Con valores custom
wsl ~/bin/helm install biblioteca-dev . -f values-dev.yaml --namespace dev --create-namespace
```

## 📁 Estructura del Chart

```
biblioteca-chart/
├── Chart.yaml                    # Metadata del chart
├── values.yaml                   # Configuración por defecto
├── values-dev.yaml               # Valores para desarrollo
├── values-prod.yaml              # Valores para producción
├── templates/                    # Templates de Kubernetes
│   ├── NOTES.txt                 # Mensaje post-instalación
│   ├── _helpers.tpl              # Funciones helper reutilizables
│   ├── configmap.yaml            # ConfigMap con variables de entorno
│   ├── secret.yaml               # Secrets (BD, New Relic)
│   ├── deployment.yaml           # Deployment de la app
│   ├── service.yaml              # Service ClusterIP/LoadBalancer
│   ├── hpa.yaml                  # Horizontal Pod Autoscaler
│   ├── postgres-pvc.yaml         # PersistentVolumeClaim para PostgreSQL
│   ├── postgres-deployment.yaml  # Deployment de PostgreSQL
│   └── postgres-service.yaml     # Service de PostgreSQL
├── .helmignore                   # Archivos a ignorar
└── README.md                     # Documentación del chart
```

## ⚙️ Configuración

### Valores Principales (values.yaml)

```yaml
# Réplicas de la aplicación
replicaCount: 2

# Imagen Docker
image:
  repository: jmejia/biblioteca-cqrs
  tag: v1.0.2
  pullPolicy: IfNotPresent

# Recursos
resources:
  requests:
    cpu: 250m
    memory: 650Mi
  limits:
    cpu: 1000m
    memory: 1Gi

# Service
service:
  type: ClusterIP  # o LoadBalancer para prod
  port: 8089

# Autoscaling
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# PostgreSQL
postgresql:
  enabled: true
  image:
    tag: 16-alpine
  persistence:
    size: 1Gi

# New Relic
newrelic:
  enabled: true
  appName: biblioteca-cqrs
  licenseKey: "31c27f317b267d415e701a03387e90d6FFFFNRAL"
```

### Personalizar Valores

**Opción 1: Archivo de valores custom**

```yaml
# mi-config.yaml
replicaCount: 5
image:
  tag: v1.0.3
resources:
  requests:
    cpu: 500m
    memory: 1Gi
```

```bash
wsl ~/bin/helm install biblioteca-custom . -f mi-config.yaml
```

**Opción 2: --set en línea de comandos**

```bash
wsl ~/bin/helm install biblioteca . \
  --set replicaCount=5 \
  --set image.tag=v1.0.3 \
  --set service.type=LoadBalancer
```

## 🌍 Ambientes

### Desarrollo

```bash
wsl ~/bin/helm install biblioteca-dev . -f values-dev.yaml -n dev --create-namespace
```

Características:
- 1 réplica
- Recursos mínimos
- HPA deshabilitado
- Logs en DEBUG

### Producción

```bash
wsl ~/bin/helm install biblioteca-prod . -f values-prod.yaml -n prod --create-namespace
```

Características:
- 3 réplicas
- Recursos altos
- HPA habilitado (3-20 pods)
- Service LoadBalancer
- Anti-affinity
- Logs en WARN/INFO

## 🔄 Operaciones

### Actualizar (Upgrade)

```bash
# Actualizar con nuevos valores
wsl ~/bin/helm upgrade biblioteca . -f values-prod.yaml

# Cambiar solo la imagen
wsl ~/bin/helm upgrade biblioteca . --set image.tag=v1.0.4

# Upgrade con espera
wsl ~/bin/helm upgrade biblioteca . --wait --timeout 5m

# Ver qué va a cambiar (dry-run)
wsl ~/bin/helm upgrade biblioteca . --dry-run --debug
```

### Ver Estado

```bash
# Listar releases
wsl ~/bin/helm list
wsl ~/bin/helm list -n prod

# Estado del release
wsl ~/bin/helm status biblioteca

# Ver valores aplicados
wsl ~/bin/helm get values biblioteca
wsl ~/bin/helm get values biblioteca --all # Con defaults

# Ver manifests generados
wsl ~/bin/helm get manifest biblioteca

# Ver historial
wsl ~/bin/helm history biblioteca
```

### Rollback

```bash
# Ver historial de revisiones
wsl ~/bin/helm history biblioteca
REVISION  UPDATED                  STATUS      CHART
1         Tue Mar 1 10:00:00 2026  superseded  biblioteca-cqrs-1.0.0
2         Wed Mar 2 14:30:00 2026  superseded  biblioteca-cqrs-1.0.0
3         Thu Mar 3 09:15:00 2026  deployed    biblioteca-cqrs-1.0.0

# Rollback a revisión anterior
wsl ~/bin/helm rollback biblioteca

# Rollback a revisión específica
wsl ~/bin/helm rollback biblioteca 2
```

### Desinstalar

```bash
# Desinstalar completamente
wsl ~/bin/helm uninstall biblioteca

# Desinstalar manteniendo historial (para rollback futuro)
wsl ~/bin/helm uninstall biblioteca --keep-history
```

## 🧪 Testing y Validación

### Validar Sintaxis

```bash
# Lint (validar sintaxis YAML y estructura)
wsl ~/bin/helm lint .

# Template render (ver YAMLs generados)
wsl ~/bin/helm template biblioteca .

# Template con valores específicos
wsl ~/bin/helm template biblioteca . -f values-prod.yaml

# Dry-run en el cluster (valida contra API de K8s)
wsl ~/bin/helm install biblioteca . --dry-run --debug
```

### Verificar Deployment

```bash
# Ver pods
kubectl get pods -l app.kubernetes.io/name=biblioteca-cqrs

# Ver todos los recursos
kubectl get all -l app.kubernetes.io/instance=biblioteca

# Ver logs
kubectl logs -l app.kubernetes.io/name=biblioteca-cqrs --tail=100 -f

# Describe pod (para troubleshooting)
kubectl describe pod <pod-name>

# Health check
kubectl exec -it <pod-name> -- curl localhost:8089/actuator/health
```

## 🔍 Troubleshooting

### Problema: Helm no encuentra Chart.yaml

**Causa:** Problema de encoding entre Windows y WSL

**Solución:** Usar el script de instalación:

```powershell
.\install-helm-chart.ps1 -Environment dev -CreateNamespace
```

### Problema: Pods no inician

```bash
# Ver eventos
kubectl get events --sort-by='.lastTimestamp'

# Describir pod
kubectl describe pod <pod-name>

# Ver logs
kubectl logs <pod-name>

# Ver logs del contenedor anterior (si crasheó)
kubectl logs pod-name> --previous
```

### Problema: Errores de conexión a BD

```bash
# Verificar servicio PostgreSQL
kubectl get svc biblioteca-postgres

# Verificar pods de PostgreSQL
kubectl get pods -l app.kubernetes.io/component=database

# Ver logs de PostgreSQL
kubectl logs <postgres-pod>

# Probar conexión desde app pod
kubectl exec -it <app-pod> -- nc -zv biblioteca-postgres 5432
```

### Problema: HPA no escala

```bash
# Verificar metrics-server
kubectl top nodes
kubectl top pods

# Ver estado del HPA
kubectl get hpa
kubectl describe hpa biblioteca
```

## 📊 Monitoring

### New Relic

Si está habilitado (`newrelic.enabled: true`), accede al dashboard:

https://one.newrelic.com/ → APM & Services → biblioteca-cqrs

### Health Checks

```bash
# Port-forward
kubectl port-forward service/biblioteca 8089:8089

# Health endpoint
curl http://localhost:8089/actuator/health

# Metrics
curl http://localhost:8089/actuator/metrics

# Info
curl http://localhost:8089/actuator/info
```

## 🔒 Seguridad

### Gestión de Secretos en Producción

**⚠️ IMPORTANTE:** No commitear secretos reales en Git

**Opción 1: Archivo separado (no commitear)**

```yaml
# secrets-prod.yaml (agregar a .gitignore)
postgresql:
  auth:
    password: "mi-contraseña-súper-segura"
newrelic:
  licenseKey: "tu-license-key-real"
```

```bash
# Instalar con archivo de secretos
wsl ~/bin/helm install biblioteca . \
  -f values-prod.yaml \
  -f secrets-prod.yaml
```

**Opción 2: Secrets externos**

```bash
# Crear secret manualmente
kubectl create secret generic biblioteca-secret \
  --from-literal=SPRING_DATASOURCE_PASSWORD=password \
  --from-literal=NEW_RELIC_LICENSE_KEY=key

# Modificar templates para referenciar este secret
```

**Opción 3: Sealed Secrets o External Secrets Operator**

- **Sealed Secrets:** Encripta secrets para commitearlos
- **External Secrets:** Sincroniza desde Vault, AWS Secrets Manager, etc.

## 📦 Empaquetar y Distribuir

```bash
# Empaquetar el chart
wsl ~/bin/helm package .

# Resultado: biblioteca-cqrs-1.0.0.tgz

# Instalar desde paquete
wsl ~/bin/helm install biblioteca ./biblioteca-cqrs-1.0.0.tgz

# Subir a repositorio Helm (ChartMuseum, Harbor, etc.)
wsl ~/bin/helm push biblioteca-cqrs-1.0.0.tgz my-repo
```

## 📚 Referencias

- **Guía Completa de Helm:** [docs/helm-guide.md](../../docs/helm-guide.md)
- **Documentación Oficial Helm:** https://helm.sh/docs/
- **Chart Best Practices:** https://helm.sh/docs/chart_best_practices/
- **Repositorio:** https://github.com/LeoUnisabana/biblioteca-cqrs-deploy

## 🆘 Ayuda

```powershell
# Ayuda del script de instalación
.\install-helm-chart.ps1 -?

# Dry-run para ver qué va a hacer
.\install-helm-chart.ps1 -Environment dev -DryRun
```

---

**Mantenedor:** Leonardo Mejía (leonardo.mejia@unisabana.edu.co)  
**Proyecto:** Biblioteca CQRS - Maestría en Arquitectura de Software  
**Universidad:** Universidad de La Sabana
