# Secret - biblioteca-secret

## 📄 Archivo: `k8s/biblioteca-secret.yaml`

## ¿Qué es un Secret?

Un **Secret** es un objeto de Kubernetes diseñado para almacenar información sensible (contraseñas, tokens, claves SSH, etc.) de forma más segura que en ConfigMaps o directamente en los manifiestos. Los datos se almacenan en formato base64.

## Contenido del Archivo

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: biblioteca-secret
type: Opaque
data:
  SPRING_DATASOURCE_PASSWORD: cG9zdGdyZXM=
```

---

## 📋 Explicación Línea por Línea

### Metadatos API

```yaml
apiVersion: v1
```
- **`apiVersion: v1`**: API core de Kubernetes
- Los Secrets están en la API estable desde el inicio

```yaml
kind: Secret
```
- **`kind`**: Tipo de recurso
- **`Secret`**: Objeto para almacenar información sensible

---

### Metadatos del Secret

```yaml
metadata:
  name: biblioteca-secret
```
- **`name`**: Nombre único del Secret en el namespace
- **`biblioteca-secret`**: Identificador usado para referenciar este Secret

---

### Tipo de Secret

```yaml
type: Opaque
```
- **`type`**: Tipo de Secret
- **`Opaque`**: Tipo genérico para datos arbitrarios (el más común)

**Otros tipos de Secrets:**
- `kubernetes.io/service-account-token`: Token de cuenta de servicio
- `kubernetes.io/dockerconfigjson`: Credenciales de registry Docker
- `kubernetes.io/tls`: Certificados TLS
- `kubernetes.io/ssh-auth`: Claves SSH
- `kubernetes.io/basic-auth`: Credenciales básicas HTTP

---

### Datos del Secret

```yaml
data:
  SPRING_DATASOURCE_PASSWORD: cG9zdGdyZXM=
```
- **`data`**: Contiene pares clave-valor en formato **base64**
- **`SPRING_DATASOURCE_PASSWORD`**: Nombre de la variable de entorno
- **`cG9zdGdyZXM=`**: Valor en base64

**Decodificación:**
```bash
echo "cG9zdGdyZXM=" | base64 --decode
# Resultado: postgres
```

**💡 Importante:** Base64 **NO es encriptación**, solo ofuscación. Cualquiera con acceso al cluster puede decodificarlo.

---

## 🔒 Seguridad de Secrets

### Nivel de Seguridad

1. **Base64 Encoding** ✅
   - Los valores están codificados, no en texto plano
   - Evita que aparezcan en logs accidentalmente

2. **RBAC (Role-Based Access Control)** ✅
   - Control de acceso mediante permisos de Kubernetes
   - Solo usuarios/servicios autorizados pueden leer Secrets

3. **Encriptación at rest** ⚠️
   - En clusters configurados correctamente
   - Los Secrets se encriptan en etcd
   - **En kind (desarrollo)**: Típicamente NO está habilitado

4. **No aparece en `kubectl describe`** ✅
   - Los valores no se muestran con comandos comunes
   - Se necesita `kubectl get secret -o yaml` explícitamente

### Mejores Prácticas de Seguridad

1. ✅ **Nunca commitear Secrets al repositorio Git**
   - Usar `.gitignore`
   - Los valores deben ser gestionados separadamente

2. ✅ **Usar herramientas de gestión de Secrets**
   - Sealed Secrets
   - External Secrets Operator
   - HashiCorp Vault
   - Cloud providers (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager)

3. ✅ **Principio de mínimo privilegio**
   - Limitar acceso a Secrets mediante RBAC
   - Cada aplicación solo accede a sus propios Secrets

4. ✅ **Rotación de Secrets**
   - Cambiar contraseñas periódicamente
   - Usar Secrets versionados

---

## 🔄 Cómo se Usa en el Deployment

```yaml
# En biblioteca-deployment.yaml
envFrom:
  - secretRef:
      name: biblioteca-secret
```

Esto inyecta todas las claves del Secret como variables de entorno en el contenedor.

**Variable resultante:**
```
SPRING_DATASOURCE_PASSWORD=postgres
```

---

## 🔧 Creación de Secrets

### Método 1: Desde archivo YAML (actual)

**Codificar valor en base64:**
```bash
echo -n "postgres" | base64
# Resultado: cG9zdGdyZXM=
```

**Aplicar el Secret:**
```bash
kubectl apply -f k8s/biblioteca-secret.yaml --context kind-biblioteca-cluster
```

### Método 2: Desde línea de comandos

```bash
kubectl create secret generic biblioteca-secret \
  --from-literal=SPRING_DATASOURCE_PASSWORD=postgres \
  --context kind-biblioteca-cluster
```

**Ventajas:**
- No necesitas codificar manualmente en base64
- kubectl lo hace automáticamente

### Método 3: Desde archivo

```bash
# Crear archivo con el password
echo -n "postgres" > password.txt

# Crear Secret desde archivo
kubectl create secret generic biblioteca-secret \
  --from-file=SPRING_DATASOURCE_PASSWORD=password.txt \
  --context kind-biblioteca-cluster

# Eliminar archivo
rm password.txt
```

---

## 🔧 Comandos Útiles

### Ver Secrets (sin valores)
```bash
kubectl get secrets --context kind-biblioteca-cluster
```

Salida:
```
NAME                TYPE     DATA   AGE
biblioteca-secret   Opaque   1      2h
```

### Describir Secret (sin valores)
```bash
kubectl describe secret biblioteca-secret --context kind-biblioteca-cluster
```

### Ver Secret completo (con valores base64)
```bash
kubectl get secret biblioteca-secret -o yaml --context kind-biblioteca-cluster
```

### Decodificar valor específico
```bash
kubectl get secret biblioteca-secret -o jsonpath='{.data.SPRING_DATASOURCE_PASSWORD}' --context kind-biblioteca-cluster | base64 --decode
```

### Editar Secret
```bash
kubectl edit secret biblioteca-secret --context kind-biblioteca-cluster
```
**Nota:** Los valores deben estar en base64

### Eliminar Secret
```bash
kubectl delete secret biblioteca-secret --context kind-biblioteca-cluster
```

### Actualizar Secret
```bash
# Opción 1: Eliminar y recrear
kubectl delete secret biblioteca-secret --context kind-biblioteca-cluster
kubectl apply -f k8s/biblioteca-secret.yaml --context kind-biblioteca-cluster

# Opción 2: Patch
kubectl patch secret biblioteca-secret -p '{"data":{"SPRING_DATASOURCE_PASSWORD":"bnVldmFfY29udHJhc2XDsWE="}}' --context kind-biblioteca-cluster
```

**💡 Importante:** Después de actualizar un Secret, reinicia los Pods:
```bash
kubectl rollout restart deployment/biblioteca-cqrs --context kind-biblioteca-cluster
```

---

## 📊 Secret vs ConfigMap

| Aspecto | Secret | ConfigMap |
|---------|--------|-----------|
| **Propósito** | Datos sensibles | Configuración no sensible |
| **Formato** | Base64 | Texto plano |
| **Visibilidad** | Oculto en describe | Visible en describe |
| **Encriptación** | Soporta at-rest | No |
| **Tamaño máximo** | 1 MB | 1 MB |
| **Uso típico** | Passwords, tokens, keys | URLs, settings, flags |

---

## ⚠️ Consideraciones de Seguridad

### NO es Seguro Para:
- ❌ Producción sin encriptación at-rest
- ❌ Commitear en Git
- ❌ Compartir públicamente

### ES Suficiente Para:
- ✅ Desarrollo local (kind)
- ✅ Ambientes de prueba
- ✅ Separar credenciales del código

### Alternativas Más Seguras:
1. **Sealed Secrets**
   - Encripta Secrets para commitear en Git
   - Se desencriptan automáticamente en el cluster

2. **External Secrets Operator**
   - Sincroniza desde proveedores externos (AWS, Azure, Vault)
   - Los valores nunca están en Git

3. **HashiCorp Vault**
   - Gestión centralizada de Secrets
   - Acceso auditado y controlado

4. **Cloud Provider Secrets**
   - AWS Secrets Manager
   - Azure Key Vault
   - GCP Secret Manager
   - Integración nativa con Kubernetes

---

## 🔗 Referencias en Otros Archivos

Este Secret es usado por:
- **`biblioteca-deployment.yaml`**: Inyecta variables de entorno mediante `secretRef`

Se usa junto con:
- **`biblioteca-configmap.yaml`**: Para variables no sensibles
- **`postgres-deployment.yaml`**: La contraseña de PostgreSQL debe coincidir

---

## 📝 Ejemplo de Secret Expandido

Para múltiples valores sensibles:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: biblioteca-secret
type: Opaque
data:
  # Database password
  SPRING_DATASOURCE_PASSWORD: cG9zdGdyZXM=
  
  # JWT Secret
  JWT_SECRET: bWlTZWNyZXRvU3VwZXJTZWd1cm8xMjM=
  
  # API Keys
  EXTERNAL_API_KEY: YXBpa2V5MTIzNDU2Nzg5MA==
  
  # New Relic License
  NEW_RELIC_LICENSE_KEY: TlJBSy1BRFpZMDlSU0RFTjA2MDFCVUJLNkdRTUxOQlM=
```

**Decodificar todos los valores:**
```bash
kubectl get secret biblioteca-secret -o json --context kind-biblioteca-cluster | \
  jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'
```

---

## 🎓 Conceptos Clave

- **Base64**: Codificación, NO encriptación
- **Opaque**: Tipo genérico para datos arbitrarios
- **RBAC**: Control de acceso a Secrets
- **At-rest encryption**: Encriptación en etcd (cluster-level)
- **Secret rotation**: Cambiar valores periódicamente
- **Immutable Secrets**: Secrets que no se pueden modificar (K8s 1.21+)

---

## 🔐 Seguridad en Producción

Para ambientes de producción, considera:

### 1. Habilitar Encriptación at-rest
```yaml
# /etc/kubernetes/enc/enc.yaml
kind: EncryptionConfiguration
apiVersion: apiserver.config.k8s.io/v1
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: <base64-encoded-secret>
```

### 2. Usar Immutable Secrets
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: biblioteca-secret
type: Opaque
immutable: true  # No se puede modificar, solo eliminar/recrear
data:
  SPRING_DATASOURCE_PASSWORD: cG9zdGdyZXM=
```

### 3. Integrar con External Secrets

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: biblioteca-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: biblioteca-secret
  data:
  - secretKey: SPRING_DATASOURCE_PASSWORD
    remoteRef:
      key: database/library
      property: password
```

---

## ✅ Checklist de Seguridad

- [ ] Secret NO está en control de versiones (Git)
- [ ] Valores están en base64
- [ ] RBAC configurado correctamente
- [ ] Encriptación at-rest habilitada (producción)
- [ ] Auditoría de acceso activada
- [ ] Plan de rotación de Secrets definido
- [ ] Backup de Secrets documentado
- [ ] Alternativa segura evaluada (Vault, External Secrets, etc.)
