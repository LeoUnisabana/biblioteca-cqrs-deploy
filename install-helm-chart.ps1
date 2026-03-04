# ================================================================
# SCRIPT DE INSTALACIÓN DE HELM CHART - BIBLIOTECA CQRS
# ================================================================
# Este script facilita la instalación del Helm Chart de Biblioteca CQRS
# Maneja problemas de encoding entre Windows y WSL automáticamente

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod", "default")]
    [string]$Environment = "default",
    
    [Parameter(Mandatory=$false)]
    [string]$ReleaseName = "biblioteca",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "default",
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateNamespace,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$Upgrade
)

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "      INSTALACION HELM CHART - BIBLIOTECA CQRS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que estamos en el directorio correcto
if (-not (Test-Path "helm/biblioteca-chart/Chart.yaml")) {
    Write-Host "Error: No se encuentra helm/biblioteca-chart/Chart.yaml" -ForegroundColor Red
    Write-Host "Ejecuta este script desde el directorio raiz del proyecto" -ForegroundColor Yellow
    exit 1
}

# Verificar que Helm está instalado en WSL
Write-Host "Verificando Helm..." -ForegroundColor Yellow
$helmCheck = wsl bash -c '~/bin/helm version 2>&1 || helm version 2>&1'
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Helm no esta instalado en WSL" -ForegroundColor Red
    Write-Host "Instalando Helm..." -ForegroundColor Yellow
    wsl bash -c 'cd /tmp && curl -LO https://get.helm.sh/helm-v3.20.0-linux-amd64.tar.gz && tar -zxvf helm-v3.20.0-linux-amd64.tar.gz && mkdir -p ~/bin && mv linux-amd64/helm ~/bin/ && chmod +x ~/bin/helm'
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error al instalar Helm" -ForegroundColor Red
        exit 1
    }
    Write-Host "Helm instalado exitosamente" -ForegroundColor Green
} else {
    Write-Host "Helm detectado correctamente" -ForegroundColor Green
}

# Verificar contexto de Kubernetes
Write-Host ""
Write-Host "Verificando cluster Kubernetes..." -ForegroundColor Yellow
$context = wsl kubectl config current-context
Write-Host "Contexto actual: $context" -ForegroundColor Cyan

if ($context -notmatch "kind-biblioteca-cluster") {
    Write-Host "Advertencia: No estas conectado al cluster kind-biblioteca-cluster" -ForegroundColor Yellow
    $continue = Read-Host "Continuar de todos modos? (s/n)"
    if ($continue -ne "s") {
        exit 0
    }
}

# Determinar archivo de valores
$valuesFile = "values.yaml"
if ($Environment -eq "dev") {
    $valuesFile = "values-dev.yaml"
    Write-Host "Ambiente: DESARROLLO" -ForegroundColor Yellow
} elseif ($Environment -eq "prod") {
    $valuesFile = "values-prod.yaml"
    Write-Host "Ambiente: PRODUCCION" -ForegroundColor Green
} else {
    Write-Host "Ambiente: DEFAULT" -ForegroundColor Cyan
}

# Construir comando Helm
$helmCmd = "~/bin/helm "
if ($Upgrade) {
    $helmCmd += "upgrade $ReleaseName "
    Write-Host "Operacion: UPGRADE" -ForegroundColor Yellow
} else {
    $helmCmd += "install $ReleaseName "
    Write-Host "Operacion: INSTALL" -ForegroundColor Green
}

$helmCmd += "/mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/helm/biblioteca-chart "

if ($Environment -ne "default") {
    $helmCmd += "-f /mnt/d/Maestria/Arquitectura/K8S/biblioteca-cqrs-deploy/helm/biblioteca-chart/$valuesFile "
}

$helmCmd += "--namespace $Namespace "

if ($CreateNamespace) {
    $helmCmd += "--create-namespace "
}

if ($DryRun) {
    $helmCmd += "--dry-run --debug "
    Write-Host "Modo: DRY-RUN (no se instalara realmente)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Release Name: $ReleaseName" -ForegroundColor Cyan
Write-Host "Namespace: $Namespace" -ForegroundColor Cyan
Write-Host "Values File: $valuesFile" -ForegroundColor Cyan
Write-Host ""

Write-Host "================================================================" -ForegroundColor DarkGray
Write-Host "Comando a ejecutar:" -ForegroundColor DarkGray
Write-Host $helmCmd -ForegroundColor DarkGray
Write-Host "================================================================" -ForegroundColor DarkGray
Write-Host ""

# Confirmar
if (-not $DryRun) {
    $confirm = Read-Host "Continuar con la instalacion? (s/n)"
    if ($confirm -ne "s") {
        Write-Host "Operacion cancelada" -ForegroundColor Yellow
        exit 0
    }
}

# Ejecutar comando Helm
Write-Host ""
Write-Host "Ejecutando instalacion..." -ForegroundColor Green
Write-Host ""

$result = wsl bash -c $helmCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "      INSTALACION EXITOSA!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    
    if (-not $DryRun) {
        # Mostrar información del release
        Write-Host "Obteniendo informacion del release..." -ForegroundColor Yellow
        wsl bash -c "~/bin/helm status $ReleaseName -n $Namespace"
        
        Write-Host ""
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "COMANDOS UTILES:" -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Ver pods:" -ForegroundColor Yellow
        Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Ver logs:" -ForegroundColor Yellow
        Write-Host "  kubectl logs -l app.kubernetes.io/name=biblioteca-cqrs -n $Namespace --tail=100 -f" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Ver release:" -ForegroundColor Yellow
        Write-Host "  wsl ~/bin/helm list -n $Namespace" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Ver valores aplicados:" -ForegroundColor Yellow
        Write-Host "  wsl ~/bin/helm get values $ReleaseName -n $Namespace" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Port-forward:" -ForegroundColor Yellow
        Write-Host "  kubectl port-forward service/$ReleaseName 8089:8089 -n $Namespace" -ForegroundColor Gray
        Write-Host ""
        
        if ($Upgrade) {
            Write-Host "Ver historial:" -ForegroundColor Yellow
            Write-Host "  wsl ~/bin/helm history $ReleaseName -n $Namespace" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Rollback (si algo falla):" -ForegroundColor Yellow
            Write-Host "  wsl ~/bin/helm rollback $ReleaseName -n $Namespace" -ForegroundColor Gray
            Write-Host ""
        }
    }
} else {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "      ERROR EN LA INSTALACION" -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "El comando Helm fallo. Revisa los errores arriba." -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Verifica que el cluster este corriendo:" -ForegroundColor Gray
    Write-Host "   kubectl get nodes" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Verifica el contexto:" -ForegroundColor Gray
    Write-Host "   kubectl config current-context" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Prueba con dry-run:" -ForegroundColor Gray
    Write-Host "   .\install-helm-chart.ps1 -Environment $Environment -DryRun" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
