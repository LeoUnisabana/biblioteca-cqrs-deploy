# Script de Despliegue con New Relic
# Este script actualiza el deployment de biblioteca-cqrs con la integración de New Relic

$ErrorActionPreference = "Stop"
$context = "kind-biblioteca-cluster"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Despliegue con New Relic Integration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar contexto de Kubernetes
Write-Host "[1/6] Verificando contexto de Kubernetes..." -ForegroundColor Yellow
$currentContext = kubectl config current-context
if ($currentContext -ne $context) {
    Write-Host "   ⚠️  Cambiando contexto a: $context" -ForegroundColor Yellow
    kubectl config use-context $context
} else {
    Write-Host "   ✅ Contexto correcto: $context" -ForegroundColor Green
}
Write-Host ""

# Eliminar el deployment anterior (para forzar recreación con initContainer)
Write-Host "[2/6] Eliminando deployment anterior..." -ForegroundColor Yellow
kubectl delete deployment biblioteca-cqrs --context $context 2>$null
if ($?) {
    Write-Host "   ✅ Deployment eliminado" -ForegroundColor Green
} else {
    Write-Host "   ℹ️  No había deployment previo" -ForegroundColor Gray
}
Write-Host ""

# Aplicar ConfigMap actualizado (con configuración de New Relic)
Write-Host "[3/6] Aplicando ConfigMap con configuración de New Relic..." -ForegroundColor Yellow
kubectl apply -f k8s/biblioteca-configmap.yaml --context $context
Write-Host "   ✅ ConfigMap aplicado" -ForegroundColor Green
Write-Host ""

# Aplicar Secret actualizado (con License Key de New Relic)
Write-Host "[4/6] Aplicando Secret con License Key de New Relic..." -ForegroundColor Yellow
kubectl apply -f k8s/biblioteca-secret.yaml --context $context
Write-Host "   ✅ Secret aplicado" -ForegroundColor Green
Write-Host ""

# Aplicar Deployment con initContainer de New Relic
Write-Host "[5/6] Aplicando Deployment con initContainer de New Relic..." -ForegroundColor Yellow
kubectl apply -f k8s/biblioteca-deployment.yaml --context $context
Write-Host "   ✅ Deployment aplicado" -ForegroundColor Green
Write-Host ""

# Esperar a que el pod esté listo
Write-Host "[6/6] Esperando a que el pod esté listo..." -ForegroundColor Yellow
Write-Host "   (Esto puede tardar ~30-40 segundos: initContainer + app startup)" -ForegroundColor Gray
Write-Host ""

$timeout = 120
$elapsed = 0
$ready = $false

while ($elapsed -lt $timeout -and -not $ready) {
    $pods = kubectl get pods -l app=biblioteca-cqrs --context $context -o json | ConvertFrom-Json
    
    if ($pods.items.Count -gt 0) {
        $pod = $pods.items[0]
        $podName = $pod.metadata.name
        $phase = $pod.status.phase
        
        # Obtener estado de containers e initContainers
        $initContainerStatus = ""
        if ($pod.status.initContainerStatuses) {
            $initState = $pod.status.initContainerStatuses[0].state
            if ($initState.running) {
                $initContainerStatus = "InitContainer ejecutándose..."
            } elseif ($initState.terminated -and $initState.terminated.exitCode -eq 0) {
                $initContainerStatus = "InitContainer completado ✅"
            } elseif ($initState.waiting) {
                $initContainerStatus = "InitContainer esperando: $($initState.waiting.reason)"
            }
        }
        
        $containerStatus = ""
        if ($pod.status.containerStatuses) {
            $containerState = $pod.status.containerStatuses[0].state
            if ($containerState.running) {
                $containerStatus = "Aplicación ejecutándose..."
            } elseif ($containerState.waiting) {
                $containerStatus = "Esperando: $($containerState.waiting.reason)"
            }
        }
        
        Write-Host "`r   Pod: $podName | Phase: $phase | $initContainerStatus $containerStatus" -NoNewline
        
        # Verificar si está listo
        if ($pod.status.conditions) {
            $readyCondition = $pod.status.conditions | Where-Object { $_.type -eq "Ready" }
            if ($readyCondition -and $readyCondition.status -eq "True") {
                $ready = $true
            }
        }
    } else {
        Write-Host "`r   Esperando creación del pod..." -NoNewline
    }
    
    if (-not $ready) {
        Start-Sleep -Seconds 3
        $elapsed += 3
    }
}

Write-Host ""
Write-Host ""

if ($ready) {
    Write-Host "   ✅ Pod listo!" -ForegroundColor Green
    Write-Host ""
    
    # Obtener nombre del pod
    $podName = (kubectl get pods -l app=biblioteca-cqrs --context $context -o jsonpath='{.items[0].metadata.name}')
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Verificación de New Relic" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "[Logs del InitContainer]" -ForegroundColor Yellow
    kubectl logs $podName -c download-newrelic-agent --context $context
    Write-Host ""
    
    Write-Host "[Verificando New Relic Agent en logs]" -ForegroundColor Yellow
    $nrLogs = kubectl logs $podName --context $context 2>$null | Select-String -Pattern "New Relic" -Context 0,2
    if ($nrLogs) {
        Write-Host "   ✅ New Relic Agent detectado en logs:" -ForegroundColor Green
        $nrLogs | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    } else {
        Write-Host "   ⚠️  No se encontraron logs de New Relic (aún puede estar inicializando)" -ForegroundColor Yellow
    }
    Write-Host ""
    
    Write-Host "[Variables de entorno de New Relic]" -ForegroundColor Yellow
    kubectl exec $podName --context $context -- env 2>$null | Select-String -Pattern "NEW_RELIC" | ForEach-Object {
        if ($_ -notmatch "LICENSE_KEY") {
            Write-Host "   $_" -ForegroundColor Gray
        } else {
            Write-Host "   NEW_RELIC_LICENSE_KEY=****" -ForegroundColor Gray
        }
    }
    Write-Host ""
    
    Write-Host "[Archivos del agente]" -ForegroundColor Yellow
    kubectl exec $podName --context $context -- ls -lh /opt/newrelic/newrelic/ 2>$null
    Write-Host ""
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Comandos útiles" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ver logs completos:" -ForegroundColor Yellow
    Write-Host "  kubectl logs $podName --context $context -f" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Port-forward:" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward service/biblioteca-service 8089:8089 --context $context" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Acceder a New Relic:" -ForegroundColor Yellow
    Write-Host "  https://one.newrelic.com/" -ForegroundColor Gray
    Write-Host "  APM & Services → biblioteca-cqrs" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Generar tráfico de prueba:" -ForegroundColor Yellow
    Write-Host "  # Después de hacer port-forward" -ForegroundColor Gray
    Write-Host "  for (`$i=1; `$i -le 50; `$i++) {" -ForegroundColor Gray
    Write-Host "    `$body = @{id=\""lib-`$i`"; titulo=\""Libro `$i`"} | ConvertTo-Json" -ForegroundColor Gray
    Write-Host "    Invoke-RestMethod -Method Post -Uri http://localhost:8089/libros -Body `$body -ContentType 'application/json'" -ForegroundColor Gray
    Write-Host "    Start-Sleep -Milliseconds 500" -ForegroundColor Gray
    Write-Host "  }" -ForegroundColor Gray
    Write-Host ""
    
} else {
    Write-Host "   ❌ Timeout esperando que el pod esté listo" -ForegroundColor Red
    Write-Host ""
    Write-Host "Ver eventos:" -ForegroundColor Yellow
    kubectl get events --sort-by='.lastTimestamp' --context $context | Select-Object -Last 10
    Write-Host ""
    Write-Host "Ver estado de pods:" -ForegroundColor Yellow
    kubectl get pods -l app=biblioteca-cqrs --context $context
}
