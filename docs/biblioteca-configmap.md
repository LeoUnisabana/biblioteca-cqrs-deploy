# ConfigMap - biblioteca-config

## 📄 Archivo: `k8s/biblioteca-configmap.yaml`

## ¿Qué es un ConfigMap?

Un **ConfigMap** es un objeto de Kubernetes que permite almacenar datos de configuración en pares clave-valor. Se utiliza para separar la configuración de la aplicación del código de la imagen del contenedor, facilitando la gestión de configuraciones específicas del entorno.

## Contenido del Archivo

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: biblioteca-config
data:
  SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-service:5432/library
  SPRING_DATASOURCE_USERNAME: postgres
```

---

## 📋 Explicación Línea por Línea

### Metadatos API

```yaml
apiVersion: v1
```
- **`apiVersion`**: Versión de la API de Kubernetes que se utiliza para este recurso
- **`v1`**: Es la versión estable de la API core de Kubernetes para ConfigMaps

```yaml
kind: ConfigMap
```
- **`kind`**: Tipo de recurso que estamos definiendo
- **`ConfigMap`**: Especifica que este es un objeto ConfigMap

---

### Metadatos del Recurso

```yaml
metadata:
  name: biblioteca-config
```
- **`metadata`**: Información sobre el objeto
- **`name`**: Nombre único del ConfigMap dentro del namespace
- **`biblioteca-config`**: Identificador que se usará para referenciar este ConfigMap desde otros recursos

---

### Datos de Configuración

```yaml
data:
```
- **`data`**: Sección que contiene todos los pares clave-valor de configuración
- Los valores aquí son **texto plano** (no encriptados)

```yaml
  SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-service:5432/library
```
- **`SPRING_DATASOURCE_URL`**: Variable de entorno que define la URL de conexión a la base de datos
- **Componentes de la URL:**
  - `jdbc:postgresql://` - Protocolo JDBC para PostgreSQL
  - `postgres-service` - Nombre del Service de Kubernetes que apunta a PostgreSQL
  - `:5432` - Puerto estándar de PostgreSQL
  - `/library` - Nombre de la base de datos

**💡 Nota Importante:** Se usa `postgres-service` en lugar de una IP porque Kubernetes proporciona DNS interno que resuelve nombres de Services a sus IPs correspondientes.

```yaml
  SPRING_DATASOURCE_USERNAME: postgres
```
- **`SPRING_DATASOURCE_USERNAME`**: Variable de entorno con el usuario de la base de datos
- **`postgres`**: Usuario por defecto de PostgreSQL

---

## 🔄 Cómo se Usa en el Deployment

El ConfigMap se inyecta en el contenedor mediante:

```yaml
# En biblioteca-deployment.yaml
envFrom:
  - configMapRef:
      name: biblioteca-config
```

Esto carga **todas** las claves del ConfigMap como variables de entorno en el contenedor.

---

## 🎯 Propósito y Beneficios

### Separación de Configuración
- La configuración está **fuera** de la imagen Docker
- Permite usar la misma imagen en diferentes entornos (dev, staging, prod)

### Facilidad de Actualización
- Cambiar configuración **sin reconstruir** la imagen
- Solo se necesita actualizar el ConfigMap y reiniciar los pods

### Service Discovery
- Usa nombres de Services (`postgres-service`) en lugar de IPs
- Kubernetes resuelve automáticamente la IP correcta

---

## 🔧 Comandos Útiles

### Aplicar el ConfigMap
```bash
kubectl apply -f k8s/biblioteca-configmap.yaml --context kind-biblioteca-cluster
```

### Ver el ConfigMap
```bash
kubectl get configmap biblioteca-config --context kind-biblioteca-cluster
```

### Ver el contenido completo
```bash
kubectl describe configmap biblioteca-config --context kind-biblioteca-cluster
```

### Ver en formato YAML
```bash
kubectl get configmap biblioteca-config -o yaml --context kind-biblioteca-cluster
```

### Editar en vivo
```bash
kubectl edit configmap biblioteca-config --context kind-biblioteca-cluster
```

### Eliminar el ConfigMap
```bash
kubectl delete configmap biblioteca-config --context kind-biblioteca-cluster
```

---

## 🔄 Actualizar Configuración

### Método 1: Modificar el archivo y reaplicar
```bash
# 1. Editar el archivo biblioteca-configmap.yaml
# 2. Aplicar cambios
kubectl apply -f k8s/biblioteca-configmap.yaml --context kind-biblioteca-cluster

# 3. Reiniciar pods para que tomen la nueva configuración
kubectl rollout restart deployment/biblioteca-cqrs --context kind-biblioteca-cluster
```

### Método 2: Editar directamente
```bash
kubectl edit configmap biblioteca-config --context kind-biblioteca-cluster
# Reiniciar deployment
kubectl rollout restart deployment/biblioteca-cqrs --context kind-biblioteca-cluster
```

---

## ⚠️ Consideraciones Importantes

### ConfigMap vs Secret
- **ConfigMap**: Para datos **NO sensibles** (URLs, nombres de usuario públicos, configuraciones)
- **Secret**: Para datos **sensibles** (contraseñas, tokens, claves API)

En nuestro caso:
- ✅ URL de la DB → ConfigMap (OK)
- ✅ Username → ConfigMap (OK, aunque podría estar en Secret)
- ❌ Password → Secret (correcto, está en `biblioteca-secret.yaml`)

### Limitaciones
- Tamaño máximo: **1 MB** por ConfigMap
- No se actualiza automáticamente en pods en ejecución
- Requiere reinicio de pods para aplicar cambios

### Mejores Prácticas
1. ✅ Usar nombres descriptivos
2. ✅ Documentar los valores
3. ✅ Versionar los ConfigMaps (ej: `biblioteca-config-v1`)
4. ✅ Combinar con Secrets para datos sensibles

---

## 🔗 Referencias en Otros Archivos

Este ConfigMap es referenciado en:
- **`biblioteca-deployment.yaml`**: Se inyecta mediante `configMapRef`

Es usado junto con:
- **`biblioteca-secret.yaml`**: Contiene la contraseña de la base de datos
- **`postgres-service.yaml`**: El Service al que apunta la URL de conexión

---

## 📝 Ejemplo de Uso Expandido

Si quisiéramos agregar más configuración:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: biblioteca-config
data:
  # Database
  SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-service:5432/library
  SPRING_DATASOURCE_USERNAME: postgres
  
  # Application
  SPRING_APPLICATION_NAME: biblioteca-cqrs
  SERVER_PORT: "8089"
  
  # Logging
  LOGGING_LEVEL_ROOT: INFO
  LOGGING_LEVEL_COM_BIBLIOTECA: DEBUG
  
  # JPA
  SPRING_JPA_SHOW_SQL: "true"
  SPRING_JPA_HIBERNATE_DDL_AUTO: validate
  
  # Actuator
  MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE: health,info,metrics
```

---

## 🎓 Conceptos Clave

- **Service Discovery**: Usar nombres de Services en lugar de IPs
- **Environment Variables**: ConfigMaps se exponen como variables de entorno
- **Declarativo**: Definir el estado deseado, Kubernetes lo mantiene
- **Inmutable**: Los valores no cambian en pods existentes hasta que se reinician
