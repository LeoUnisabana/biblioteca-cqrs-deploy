# Biblioteca CQRS - Helm Chart

Sistema de gestión de biblioteca con arquitectura CQRS/Event Sourcing desplegable en Kubernetes usando Helm.

## 📋 Descripción

Este Helm Chart despliega la aplicación Biblioteca CQRS completa, incluyendo:
- ☕ Aplicación Spring Boot con arquitectura CQRS
- 🐘 PostgreSQL como base de datos
- 📊 Integración con New Relic APM
- 🔄 Horizontal Pod Autoscaler (HPA)
- 🛡️ Health checks configurables
- 🎯 Múltiples ambientes (dev, prod)

## 🚀 Instalación Rápida

### Prerequisitos

- Kubernetes 1.19+
- Helm 3.0+
- Cluster con soporte para PersistentVolumes

### Instalación Básica

```bash
# Agregar el repositorio (si está publicado)
helm repo add biblioteca https://github.com/LeoUnisabana/biblioteca-cqrs-deploy
helm repo update

# Instalar el chart
helm install biblioteca ./biblioteca-chart

# O instalar desde el repositorio Git
git clone https://github.com/LeoUnisabana/biblioteca-cqrs-deploy.git
cd biblioteca-cqrs-deploy/helm
helm install biblioteca ./biblioteca-chart
```

### Instalación con Valores Personalizados

```bash
# Ambiente de desarrollo
helm install biblioteca-dev ./biblioteca-chart -f ./biblioteca-chart/values-dev.yaml

# Ambiente de producción
helm install biblioteca-prod ./biblioteca-chart -f ./biblioteca-chart/values-prod.yaml

# Sobreescribir valores específicos
helm install biblioteca ./biblioteca-chart \
  --set replicaCount=3 \
  --set image.tag=v1.0.3 \
  --set service.type=LoadBalancer
```

## ⚙️ Configuración

### Valores Principales

| Parámetro | Descripción | Valor por Defecto |
|-----------|-------------|-------------------|
| `replicaCount` | Número de réplicas | `2` |
| `image.repository` | Repositorio de la imagen | `jmejia/biblioteca-cqrs` |
| `image.tag` | Tag de la imagen | `v1.0.2` |
| `image.pullPolicy` | Política de pull | `IfNotPresent` |
| `service.type` | Tipo de servicio | `ClusterIP` |
| `service.port` | Puerto del servicio | `8089` |
| `resources.requests.cpu` | CPU solicitada | `250m` |
| `resources.requests.memory` | Memoria solicitada | `650Mi` |

### PostgreSQL

| Parámetro | Descripción | Valor por Defecto |
|-----------|-------------|-------------------|
| `postgresql.enabled` | Habilitar PostgreSQL incluido | `true` |
| `postgresql.image.tag` | Versión de PostgreSQL | `16-alpine` |
| `postgresql.auth.database` | Nombre de la base de datos | `biblioteca_db` |
| `postgresql.auth.username` | Usuario de la BD | `biblioteca_user` |
| `postgresql.auth.password` | Contraseña de la BD | `biblioteca_pass` |
| `postgresql.persistence.size` | Tamaño del volumen | `1Gi` |

### New Relic

| Parámetro | Descripción | Valor por Defecto |
|-----------|-------------|-------------------|
| `newrelic.enabled` | Habilitar New Relic APM | `true` |
| `newrelic.appName` | Nombre de la app en New Relic | `biblioteca-cqrs` |
| `newrelic.licenseKey` | License Key de New Relic | - |
| `newrelic.distributedTracingEnabled` | Habilitar distributed tracing | `true` |

### Autoscaling (HPA)

| Parámetro | Descripción | Valor por Defecto |
|-----------|-------------|-------------------|
| `autoscaling.enabled` | Habilitar HPA | `true` |
| `autoscaling.minReplicas` | Mínimo de réplicas | `2` |
| `autoscaling.maxReplicas` | Máximo de réplicas | `10` |
| `autoscaling.targetCPUUtilizationPercentage` | CPU objetivo | `70` |
| `autoscaling.targetMemoryUtilizationPercentage` | Memoria objetivo | `80` |

## 🔧 Comandos Útiles

### Ver estado del release

```bash
helm status biblioteca
helm list
```

### Ver valores aplicados

```bash
helm get values biblioteca
helm get values biblioteca --all  # Incluye valores por defecto
```

### Actualizar el release

```bash
# Actualizar con nuevos valores
helm upgrade biblioteca ./biblioteca-chart -f custom-values.yaml

# Actualizar solo la imagen
helm upgrade biblioteca ./biblioteca-chart --set image.tag=v1.0.3

# Actualizar y esperar hasta que esté listo
helm upgrade biblioteca ./biblioteca-chart --wait --timeout 5m
```

### Rollback

```bash
# Ver historial
helm history biblioteca

# Rollback a revisión anterior
helm rollback biblioteca

# Rollback a revisión específica
helm rollback biblioteca 2
```

### Desinstalar

```bash
helm uninstall biblioteca

# Mantener el historial
helm uninstall biblioteca --keep-history
```

### Testing

```bash
# Renderizar templates sin instalar (dry-run)
helm install biblioteca ./biblioteca-chart --dry-run --debug

# Validar templates
helm template biblioteca ./biblioteca-chart

# Lint (validar sintaxis)
helm lint ./biblioteca-chart
```

## 🌍 Ambientes

### Desarrollo

```bash
helm install biblioteca-dev ./biblioteca-chart \
  -f ./biblioteca-chart/values-dev.yaml \
  --namespace dev --create-namespace
```

Características:
- 1 réplica
- Recursos mínimos
- HPA deshabilitado
- Logs en modo DEBUG
- Pull policy: Always

### Producción

```bash
helm install biblioteca-prod ./biblioteca-chart \
  -f ./biblioteca-chart/values-prod.yaml \
  --namespace prod --create-namespace
```

Características:
- 3+ réplicas
- Recursos optimizados
- HPA habilitado (3-20 pods)
- Service tipo LoadBalancer
- Anti-affinity para distribución de pods
- Logs en modo WARN/INFO

## 📊 Monitoreo

### Health Checks

La aplicación expone endpoints de health check:

```bash
# Verificar health
kubectl exec -it <pod-name> -- curl localhost:8089/actuator/health

# Ver métricas
kubectl exec -it <pod-name> -- curl localhost:8089/actuator/metrics
```

### New Relic

Si está habilitado, accede al dashboard en:
- https://one.newrelic.com/
- APM & Services → biblioteca-cqrs

### Logs

```bash
# Ver logs en tiempo real
kubectl logs -f deployment/biblioteca-cqrs

# Ver logs de todos los pods
kubectl logs -l app.kubernetes.io/name=biblioteca-cqrs --tail=100 -f
```

## 🔒 Seguridad

### Secrets en Producción

**⚠️ IMPORTANTE:** Los valores por defecto incluyen contraseñas de ejemplo. En producción:

1. **Opción 1:** Usar archivo de valores separado (NO commitear)

```bash
# secrets-prod.yaml (agregar a .gitignore)
postgresql:
  auth:
    password: "mi-contraseña-segura"

newrelic:
  licenseKey: "mi-license-key-real"
```

```bash
helm install biblioteca ./biblioteca-chart \
  -f values-prod.yaml \
  -f secrets-prod.yaml
```

2. **Opción 2:** Usar secrets externos

```bash
# Crear secret manualmente
kubectl create secret generic biblioteca-secret \
  --from-literal=SPRING_DATASOURCE_PASSWORD=password \
  --from-literal=NEW_RELIC_LICENSE_KEY=key

# Modificar templates para usar este secret
```

3. **Opción 3:** Usar herramientas como Sealed Secrets o External Secrets Operator

## 🧪 Testing de Carga

Incluye script de simulación de tráfico:

```bash
# Activar port-forward
kubectl port-forward service/biblioteca-cqrs 8089:8089

# Ejecutar simulación
./traffic-simulation.ps1 -Duration 300 -Intensity High -Pattern Wave
```

## 🐛 Troubleshooting

### Pod no inicia

```bash
# Ver eventos
kubectl get events --sort-by='.lastTimestamp'

# Describir pod
kubectl describe pod <pod-name>

# Ver logs
kubectl logs <pod-name> --previous  # Logs del contenedor anterior si crasheó
```

### Base de datos no conecta

```bash
# Verificar servicio PostgreSQL
kubectl get svc biblioteca-cqrs-postgres
kubectl get pods -l app.kubernetes.io/component=database

# Probar conexión desde el pod
kubectl exec -it <app-pod> -- curl -v telnet://biblioteca-cqrs-postgres:5432
```

### HPA no escala

```bash
# Verificar metrics-server
kubectl top nodes
kubectl top pods

# Ver HPA
kubectl get hpa
kubectl describe hpa biblioteca-cqrs
```

## 📦 Empaquetar Chart

```bash
# Empaquetar
helm package ./biblioteca-chart

# Resultado: biblioteca-cqrs-1.0.0.tgz

# Instalar desde paquete
helm install biblioteca ./biblioteca-cqrs-1.0.0.tgz
```

## 🔗 Links Útiles

- **Repositorio:** https://github.com/LeoUnisabana/biblioteca-cqrs-deploy
- **Issues:** https://github.com/LeoUnisabana/biblioteca-cqrs-deploy/issues
- **Documentación Helm:** https://helm.sh/docs/
- **New Relic:** https://one.newrelic.com/

## 📄 Licencia

Este proyecto es parte de un trabajo académico de la Maestría en Arquitectura de Software - Universidad de La Sabana.

## 👤 Autor

**Leonardo Mejía**
- GitHub: [@LeoUnisabana](https://github.com/LeoUnisabana)
- Email: leonardo.mejia@unisabana.edu.co

---

**Nota:** Este chart está diseñado para propósitos educativos y de demostración. Para uso en producción, asegúrate de revisar y ajustar las configuraciones de seguridad, recursos y monitoreo según tus necesidades.
