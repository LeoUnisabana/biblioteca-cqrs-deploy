# 🚦 Simulación de Tráfico - Biblioteca CQRS

Scripts para generar tráfico realista en la API de Biblioteca CQRS y visualizar métricas en New Relic.

---

## 📋 Scripts Disponibles

### 1. **traffic-simulation.ps1** - Simulador Completo

Script avanzado con múltiples opciones de configuración.

#### **Parámetros:**

| Parámetro | Descripción | Valores | Default |
|-----------|-------------|---------|---------|
| `-Duration` | Duración en segundos | Número entero | `60` |
| `-Intensity` | Intensidad del tráfico | `Low`, `Medium`, `High`, `Extreme` | `Medium` |
| `-Pattern` | Patrón de tráfico | `Steady`, `Burst`, `Wave`, `Stress` | `Steady` |
| `-BaseUrl` | URL de la API | URL válida | `http://localhost:8089` |
| `-ShowMetrics` | Mostrar métricas cada 5s | Switch | `false` |

#### **Intensidades:**

- **Low**: 2 req/s (~120 requests/minuto)
- **Medium**: 5 req/s (~300 requests/minuto)
- **High**: 10 req/s (~600 requests/minuto)
- **Extreme**: 20 req/s (~1200 requests/minuto)

#### **Patrones de Tráfico:**

- **Steady**: Tráfico constante y uniforme
- **Burst**: Ráfagas intensas cada 10 segundos
- **Wave**: Patrón sinusoidal (sube y baja gradualmente)
- **Stress**: Incremento progresivo de carga

#### **Operaciones Simuladas:**

- ✅ **25%**: Crear libros (POST `/libros`)
- 📖 **35%**: Consultar libros (GET `/libros/{id}`)
- 📤 **15%**: Prestar libros (POST `/libros/prestar`)
- 📥 **10%**: Devolver libros (POST `/libros/devolver/{id}`)
- ❌ **15%**: Errores 404 intencionales

---

### 2. **quick-traffic.ps1** - Simulador Rápido

Script simple para generar tráfico básico rápidamente.

#### **Parámetros:**

| Parámetro | Descripción | Default |
|-----------|-------------|---------|
| `-Requests` | Número de requests | `50` |
| `-BaseUrl` | URL de la API | `http://localhost:8089` |

---

## 🚀 Ejemplos de Uso

### **Ejemplo 1: Tráfico Medio por 2 Minutos**
```powershell
.\traffic-simulation.ps1 -Duration 120 -Intensity Medium -Pattern Steady
```

### **Ejemplo 2: Tráfico Alto con Ráfagas (3 minutos)**
```powershell
.\traffic-simulation.ps1 -Duration 180 -Intensity High -Pattern Burst -ShowMetrics
```

### **Ejemplo 3: Prueba de Estrés (5 minutos)**
```powershell
.\traffic-simulation.ps1 -Duration 300 -Intensity Extreme -Pattern Stress -ShowMetrics
```

### **Ejemplo 4: Tráfico Ondulante Prolongado (10 minutos)**
```powershell
.\traffic-simulation.ps1 -Duration 600 -Intensity Medium -Pattern Wave -ShowMetrics
```

### **Ejemplo 5: Simulación Rápida de 100 Requests**
```powershell
.\quick-traffic.ps1 -Requests 100
```

### **Ejemplo 6: Simulación Rápida de 500 Requests**
```powershell
.\quick-traffic.ps1 -Requests 500
```

---

## 📊 Métricas Generadas

### **Durante la Simulación:**
- ⏱️  Tiempo transcurrido
- 📊 Total de requests
- ✅ Requests exitosos (con % de éxito)
- ❌ Requests fallidos
- ⚡ Throughput (req/s)
- 🕐 Tiempo de respuesta promedio
- 📚 Libros creados
- 📤 Libros prestados
- 📥 Libros devueltos
- 🔍 Errores 404

### **Al Finalizar:**
- Resumen completo de estadísticas
- Breakdown por tipo de request (POST, GET, PUT)
- Throughput final
- Tiempo de respuesta promedio
- Link a New Relic Dashboard

---

## 🔧 Prerequisitos

1. **Port-Forward Activo:**
   ```powershell
   kubectl port-forward service/biblioteca-service 8089:8089 --context kind-biblioteca-cluster
   ```
   
   O en una ventana separada minimizada:
   ```powershell
   Start-Process powershell -ArgumentList "-NoExit", "-Command", "wsl kubectl port-forward service/biblioteca-service 8089:8089 --context kind-biblioteca-cluster" -WindowStyle Minimized
   ```

2. **Verificar Conectividad:**
   ```powershell
   Invoke-RestMethod -Uri http://localhost:8089/actuator/health
   ```
   
   Debe retornar: `status: UP`

---

## 🌐 Visualización en New Relic

### **Acceso:**
1. Ir a: https://one.newrelic.com/
2. Navegar a: **APM & Services** → **biblioteca-cqrs**
3. O directamente: https://rpm.newrelic.com/accounts/7785285/applications/495590663

### **Métricas a Observar:**

#### **1. Overview**
- **Web transactions time**: Tiempo de respuesta
- **Throughput**: Requests por minuto
- **Error rate**: Porcentaje de errores
- **Apdex score**: Satisfacción del usuario

#### **2. Transactions**
- `/libros` (POST): Registro de libros
- `/libros/{id}` (GET): Consulta de libros
- `/libros/prestar` (POST): Préstamos
- `/libros/devolver/{id}` (POST): Devoluciones

#### **3. Databases**
- Queries más lentas
- Tiempo total en DB
- Throughput de queries

#### **4. JVM**
- Heap memory usage
- Garbage collection
- Thread count
- CPU usage

#### **5. Distributed Tracing**
- Request flow completo
- Identificar cuellos de botella
- Latencia por componente

#### **6. Errors**
- Error rate por transacción
- Stack traces
- Clasificación por tipo

---

## 🎯 Escenarios Recomendados

### **Escenario 1: Demo / Presentación**
```powershell
.\traffic-simulation.ps1 -Duration 180 -Intensity Medium -Pattern Wave -ShowMetrics
```
**Objetivo**: Mostrar métricas variadas durante una demostración de 3 minutos.

### **Escenario 2: Prueba de Carga**
```powershell
.\traffic-simulation.ps1 -Duration 300 -Intensity High -Pattern Steady -ShowMetrics
```
**Objetivo**: Evaluar comportamiento bajo carga sostenida por 5 minutos.

### **Escenario 3: Prueba de Escalabilidad**
```powershell
# Primero con intensidad baja
.\traffic-simulation.ps1 -Duration 120 -Intensity Low -Pattern Steady

# Luego con intensidad alta
.\traffic-simulation.ps1 -Duration 120 -Intensity High -Pattern Steady

# Finalmente extrema
.\traffic-simulation.ps1 -Duration 120 -Intensity Extreme -Pattern Stress
```
**Objetivo**: Ver cómo escala la aplicación con diferentes cargas.

### **Escenario 4: Detección de Problemas**
```powershell
.\traffic-simulation.ps1 -Duration 600 -Intensity Medium -Pattern Burst -ShowMetrics
```
**Objetivo**: Simular tráfico realista con picos para detectar problemas de performance.

### **Escenario 5: Datos Iniciales Rápidos**
```powershell
.\quick-traffic.ps1 -Requests 200
```
**Objetivo**: Generar datos de prueba rápidamente para empezar a ver métricas.

---

## 📈 Interpretación de Resultados

### **Buenos Resultados:**
- ✅ Success Rate > 99%
- ✅ Avg Response Time < 200ms
- ✅ Throughput según intensidad esperada
- ✅ Sin errores inesperados (solo 404 intencionales)

### **Señales de Alerta:**
- ⚠️ Success Rate < 95%
- ⚠️ Avg Response Time > 500ms
- ⚠️ Throughput inconsistente
- ⚠️ Errores 500 (Internal Server Error)

### **Problemas Críticos:**
- 🔴 Success Rate < 90%
- 🔴 Avg Response Time > 1000ms
- 🔴 Pod reiniciándose (RESTARTS > 0)
- 🔴 Errors 503 (Service Unavailable)

---

## 🛠️ Troubleshooting

### **Error: No se puede conectar**
```
❌ Error: No se puede conectar a http://localhost:8089
```

**Solución:**
1. Verificar que el port-forward está activo
2. Verificar que el pod está corriendo (`kubectl get pods`)
3. Revisar logs del pod (`kubectl logs <pod-name>`)

### **Error: Requests muy lentos**
**Posibles causas:**
1. Base de datos saturada
2. Recursos de CPU/memoria insuficientes
3. Muchos requests concurrentes

**Solución:**
1. Reducir intensidad del tráfico
2. Verificar recursos en Kubernetes
3. Escalar horizontalmente (aumentar réplicas)

### **Error: Muchos requests fallan**
**Posibles causas:**
1. Aplicación crasheando
2. Health probes fallando
3. Timeout de conexión

**Solución:**
1. Verificar logs de la aplicación
2. Verificar estado del pod
3. Revisar eventos de Kubernetes

---

## 📝 Notas Adicionales

- Los scripts generan datos de prueba (libros con IDs `lib-sim-XXXXX` y `lib-quick-XXX`)
- Los errores 404 son intencionales y simulan usuarios buscando recursos inexistentes
- Las métricas en New Relic pueden tardar 1-2 minutos en aparecer
- Se recomienda ejecutar simulaciones de al menos 2 minutos para ver datos significativos
- Para pruebas de estrés prolongadas, monitorear recursos del cluster

---

## 🔗 Referencias

- [New Relic APM](https://docs.newrelic.com/docs/apm/)
- [Kubernetes Monitoring](https://docs.newrelic.com/docs/kubernetes-pixie/kubernetes-integration/)
- [Performance Testing Best Practices](https://docs.newrelic.com/docs/new-relic-solutions/best-practices-guides/)
