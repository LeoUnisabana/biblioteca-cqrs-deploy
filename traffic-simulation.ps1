<#
.SYNOPSIS
    Simulador de Tráfico para Biblioteca CQRS - Genera tráfico realista para monitoreo con New Relic

.DESCRIPTION
    Este script simula usuarios reales interactuando con la API de biblioteca CQRS:
    - Registro de libros
    - Consultas de libros
    - Préstamos y devoluciones
    - Errores intencionales (404, etc.)
    - Diferentes patrones de carga (normal, pico, estrés)

.PARAMETER Duration
    Duración de la simulación en segundos (default: 60)

.PARAMETER Intensity
    Intensidad del tráfico: Low, Medium, High, Extreme (default: Medium)

.PARAMETER Pattern
    Patrón de tráfico: Steady, Burst, Wave, Stress (default: Steady)

.PARAMETER BaseUrl
    URL base de la API (default: http://localhost:8089)

.EXAMPLE
    .\traffic-simulation.ps1 -Duration 120 -Intensity High -Pattern Wave
#>

param(
    [int]$Duration = 60,
    [ValidateSet("Low", "Medium", "High", "Extreme")]
    [string]$Intensity = "Medium",
    [ValidateSet("Steady", "Burst", "Wave", "Stress")]
    [string]$Pattern = "Steady",
    [string]$BaseUrl = "http://localhost:8089",
    [switch]$ShowMetrics
)

# Configuración de colores
$colors = @{
    Success = "Green"
    Error = "Red"
    Info = "Cyan"
    Warning = "Yellow"
    Metric = "Magenta"
}

# Configuración de intensidad (requests por segundo)
$intensityConfig = @{
    Low = 2
    Medium = 5
    High = 10
    Extreme = 20
}

# Estadísticas globales
$stats = @{
    TotalRequests = 0
    SuccessfulRequests = 0
    FailedRequests = 0
    PostRequests = 0
    GetRequests = 0
    PutRequests = 0
    Errors404 = 0
    AvgResponseTime = 0
    TotalResponseTime = 0
    LibrosCreados = 0
    LibrosPrestados = 0
    LibrosDevueltos = 0
}

# Datos de ejemplo para libros
$titulos = @(
    "Kubernetes in Action",
    "Docker Deep Dive",
    "DevOps Handbook",
    "Site Reliability Engineering",
    "Cloud Native Patterns",
    "Microservices Patterns",
    "Continuous Delivery",
    "The Phoenix Project",
    "Infrastructure as Code",
    "Building Microservices",
    "Domain-Driven Design",
    "Clean Architecture",
    "Designing Data-Intensive Applications",
    "Release It!",
    "The DevOps Handbook"
)

$autores = @(
    "Martin Fowler",
    "Robert C. Martin",
    "Eric Evans",
    "Gene Kim",
    "Jez Humble",
    "Sam Newman",
    "Kelsey Hightower",
    "Brendan Burns",
    "Joe Beda",
    "Chris Richardson"
)

# Función para generar ISBN aleatorio
function Get-RandomISBN {
    "978-" + (Get-Random -Minimum 1000000000 -Maximum 9999999999)
}

# Función para obtener delay según intensidad y patrón
function Get-RequestDelay {
    param(
        [int]$ElapsedSeconds,
        [int]$TotalDuration
    )
    
    $baseDelay = 1000 / $intensityConfig[$Intensity]
    
    switch ($Pattern) {
        "Steady" {
            return $baseDelay
        }
        "Burst" {
            # Ráfagas cada 10 segundos
            if (($ElapsedSeconds % 10) -lt 3) {
                return $baseDelay / 3
            }
            return $baseDelay * 2
        }
        "Wave" {
            # Onda sinusoidal
            $wave = [Math]::Sin($ElapsedSeconds / $TotalDuration * [Math]::PI * 2)
            return $baseDelay * (1 + $wave) / 2 + 50
        }
        "Stress" {
            # Incremento progresivo
            $factor = 1 - ($ElapsedSeconds / $TotalDuration * 0.8)
            return $baseDelay * $factor
        }
    }
}

# Función para hacer request y medir tiempo
function Invoke-TimedRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [string]$Body = $null,
        [bool]$ExpectError = $false
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $success = $false
    
    try {
        $params = @{
            Method = $Method
            Uri = $Uri
            ContentType = "application/json"
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            $params.Body = $Body
        }
        
        $response = Invoke-RestMethod @params
        $success = $true
        $stats.SuccessfulRequests++
        
    } catch {
        if ($ExpectError) {
            $success = $true
            $stats.SuccessfulRequests++
        } else {
            $stats.FailedRequests++
            if ($_.Exception.Response.StatusCode -eq 404) {
                $stats.Errors404++
            }
        }
    } finally {
        $stopwatch.Stop()
        $stats.TotalRequests++
        $stats.TotalResponseTime += $stopwatch.ElapsedMilliseconds
        
        switch ($Method) {
            "Post" { $stats.PostRequests++ }
            "Get" { $stats.GetRequests++ }
            "Put" { $stats.PutRequests++ }
        }
    }
    
    return @{
        Success = $success
        ElapsedMs = $stopwatch.ElapsedMilliseconds
    }
}

# Función para registrar un libro
function New-RandomLibro {
    $id = "lib-sim-" + (Get-Random -Minimum 10000 -Maximum 99999)
    $titulo = $titulos | Get-Random
    $autor = $autores | Get-Random
    $isbn = Get-RandomISBN
    
    $libro = @{
        id = $id
        titulo = $titulo
        autor = $autor
        isbn = $isbn
    } | ConvertTo-Json
    
    $result = Invoke-TimedRequest -Method "Post" -Uri "$BaseUrl/libros" -Body $libro
    
    if ($result.Success) {
        $stats.LibrosCreados++
        Write-Host "  [POST] " -ForegroundColor $colors.Success -NoNewline
        Write-Host "Libro creado: $id " -NoNewline
        Write-Host "($($result.ElapsedMs)ms)" -ForegroundColor Gray
    }
    
    return $id
}

# Función para consultar un libro
function Get-RandomLibro {
    param([string]$LibroId)
    
    $result = Invoke-TimedRequest -Method "Get" -Uri "$BaseUrl/libros/$LibroId"
    
    if ($result.Success) {
        Write-Host "  [GET]  " -ForegroundColor $colors.Info -NoNewline
        Write-Host "Libro consultado: $LibroId " -NoNewline
        Write-Host "($($result.ElapsedMs)ms)" -ForegroundColor Gray
    }
}

# Función para prestar un libro
function Invoke-PrestamoLibro {
    param([string]$LibroId)
    
    $usuarioId = "user-" + (Get-Random -Minimum 100 -Maximum 999)
    $prestamo = @{
        libroId = $LibroId
        usuarioId = $usuarioId
    } | ConvertTo-Json
    
    $result = Invoke-TimedRequest -Method "Post" -Uri "$BaseUrl/libros/prestar" -Body $prestamo
    
    if ($result.Success) {
        $stats.LibrosPrestados++
        Write-Host "  [POST] " -ForegroundColor $colors.Warning -NoNewline
        Write-Host "Libro prestado: $LibroId → $usuarioId " -NoNewline
        Write-Host "($($result.ElapsedMs)ms)" -ForegroundColor Gray
    }
}

# Función para devolver un libro
function Invoke-DevolucionLibro {
    param([string]$LibroId)
    
    $result = Invoke-TimedRequest -Method "Post" -Uri "$BaseUrl/libros/devolver/$LibroId"
    
    if ($result.Success) {
        $stats.LibrosDevueltos++
        Write-Host "  [POST] " -ForegroundColor $colors.Success -NoNewline
        Write-Host "Libro devuelto: $LibroId " -NoNewline
        Write-Host "($($result.ElapsedMs)ms)" -ForegroundColor Gray
    }
}

# Función para generar error 404 intencional
function Invoke-ErrorRequest {
    $fakeId = "libro-inexistente-" + (Get-Random -Minimum 1000 -Maximum 9999)
    
    $result = Invoke-TimedRequest -Method "Get" -Uri "$BaseUrl/libros/$fakeId" -ExpectError $true
    
    Write-Host "  [GET]  " -ForegroundColor $colors.Error -NoNewline
    Write-Host "404 intencional: $fakeId " -NoNewline
    Write-Host "($($result.ElapsedMs)ms)" -ForegroundColor Gray
    
    $stats.Errors404++
}

# Función para mostrar cabecera
function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "      SIMULADOR DE TRAFICO - BIBLIOTECA CQRS + NEW RELIC      " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Duracion:     $Duration segundos" -ForegroundColor Yellow
    Write-Host "  Intensidad:   $Intensity ($($intensityConfig[$Intensity]) req/s)" -ForegroundColor Yellow
    Write-Host "  Patron:       $Pattern" -ForegroundColor Yellow
    Write-Host "  URL Base:     $BaseUrl" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

# Función para mostrar métricas en tiempo real
function Show-Metrics {
    param([int]$ElapsedSeconds)
    
    $avgResponseTime = if ($stats.TotalRequests -gt 0) { 
        [math]::Round($stats.TotalResponseTime / $stats.TotalRequests, 2) 
    } else { 0 }
    
    $successRate = if ($stats.TotalRequests -gt 0) { 
        [math]::Round(($stats.SuccessfulRequests / $stats.TotalRequests) * 100, 2) 
    } else { 0 }
    
    $throughput = if ($ElapsedSeconds -gt 0) { 
        [math]::Round($stats.TotalRequests / $ElapsedSeconds, 2) 
    } else { 0 }
    
    Write-Host "`n[- METRICAS EN TIEMPO REAL ---------------------------------]" -ForegroundColor Magenta
    Write-Host "| Tiempo:          $ElapsedSeconds / $Duration segundos" -ForegroundColor White
    Write-Host "| Total Requests:   $($stats.TotalRequests)" -ForegroundColor White
    Write-Host "| Exitosos:         $($stats.SuccessfulRequests) ($successRate%)" -ForegroundColor Green
    Write-Host "| Fallidos:         $($stats.FailedRequests)" -ForegroundColor Red
    Write-Host "| Throughput:       $throughput req/s" -ForegroundColor Yellow
    Write-Host "| Avg Response:     ${avgResponseTime}ms" -ForegroundColor Yellow
    Write-Host "|" -ForegroundColor Magenta
    Write-Host "| Libros Creados:   $($stats.LibrosCreados)" -ForegroundColor White
    Write-Host "| Libros Prestados: $($stats.LibrosPrestados)" -ForegroundColor White
    Write-Host "| Libros Devueltos: $($stats.LibrosDevueltos)" -ForegroundColor White
    Write-Host "| Errores 404:      $($stats.Errors404)" -ForegroundColor White
    Write-Host "[------------------------------------------------------------]" -ForegroundColor Magenta
    Write-Host ""
}

# Función principal de simulación
function Start-TrafficSimulation {
    Show-Header
    
    # Verificar conectividad
    Write-Host "Verificando conectividad con $BaseUrl..." -ForegroundColor Yellow
    try {
        $health = Invoke-RestMethod -Uri "$BaseUrl/actuator/health" -ErrorAction Stop
        Write-Host "Conexion exitosa - Status: $($health.status)" -ForegroundColor Green
        Write-Host ""
    } catch {
        Write-Host "Error: No se puede conectar a $BaseUrl" -ForegroundColor Red
        Write-Host "Asegurate de tener el port-forward activo:" -ForegroundColor Yellow
        Write-Host "  kubectl port-forward service/biblioteca-service 8089:8089 --context kind-biblioteca-cluster" -ForegroundColor Gray
        Write-Host ""
        return
    }
    
    Write-Host "Iniciando simulacion de trafico..." -ForegroundColor Green
    Write-Host ""
    Start-Sleep -Seconds 2
    
    $startTime = Get-Date
    $librosCreados = @()
    $librosParaPrestar = @()
    $librosParaDevolver = @()
    
    while (((Get-Date) - $startTime).TotalSeconds -lt $Duration) {
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        
        # Determinar acción a realizar (ponderada)
        $random = Get-Random -Minimum 1 -Maximum 100
        
        if ($random -le 25) {
            # 25% - Crear libro
            $id = New-RandomLibro
            $librosCreados += $id
            $librosParaPrestar += $id
            
        } elseif ($random -le 60 -and $librosCreados.Count -gt 0) {
            # 35% - Consultar libro existente
            $libro = $librosCreados | Get-Random
            Get-RandomLibro -LibroId $libro
            
        } elseif ($random -le 75 -and $librosParaPrestar.Count -gt 0) {
            # 15% - Prestar libro
            $libro = $librosParaPrestar[0]
            Invoke-PrestamoLibro -LibroId $libro
            $librosParaPrestar = $librosParaPrestar | Where-Object { $_ -ne $libro }
            $librosParaDevolver += $libro
            
        } elseif ($random -le 85 -and $librosParaDevolver.Count -gt 0) {
            # 10% - Devolver libro
            $libro = $librosParaDevolver[0]
            Invoke-DevolucionLibro -LibroId $libro
            $librosParaDevolver = $librosParaDevolver | Where-Object { $_ -ne $libro }
            $librosParaPrestar += $libro
            
        } else {
            # 15% - Generar error 404
            Invoke-ErrorRequest
        }
        
        # Mostrar métricas cada 5 segundos
        if ($ShowMetrics -and ($elapsed % 5 -eq 0)) {
            Show-Metrics -ElapsedSeconds $elapsed
        }
        
        # Calcular delay según patrón
        $delay = Get-RequestDelay -ElapsedSeconds $elapsed -TotalDuration $Duration
        Start-Sleep -Milliseconds $delay
    }
    
    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host "                    SIMULACION COMPLETADA" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    
    $finalAvgResponseTime = [math]::Round($stats.TotalResponseTime / $stats.TotalRequests, 2)
    $finalSuccessRate = [math]::Round(($stats.SuccessfulRequests / $stats.TotalRequests) * 100, 2)
    $finalThroughput = [math]::Round($stats.TotalRequests / $Duration, 2)
    
    Write-Host ""
    Write-Host "  Total de Requests:       $($stats.TotalRequests)" -ForegroundColor White
    Write-Host "  Requests Exitosos:       $($stats.SuccessfulRequests) ($finalSuccessRate%25)" -ForegroundColor Green
    Write-Host "  Requests Fallidos:       $($stats.FailedRequests)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  POST (Creacion):         $($stats.PostRequests)" -ForegroundColor Yellow
    Write-Host "  GET (Consulta):          $($stats.GetRequests)" -ForegroundColor Cyan
    Write-Host "  PUT/PATCH:               $($stats.PutRequests)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Libros Creados:          $($stats.LibrosCreados)" -ForegroundColor White
    Write-Host "  Prestamos:               $($stats.LibrosPrestados)" -ForegroundColor White
    Write-Host "  Devoluciones:            $($stats.LibrosDevueltos)" -ForegroundColor White
    Write-Host "  Errores 404:             $($stats.Errors404)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Throughput:              $finalThroughput req/s" -ForegroundColor Yellow
    Write-Host "  Tiempo Promedio:         ${finalAvgResponseTime}ms" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ver metricas en New Relic:" -ForegroundColor Green
    Write-Host "   https://one.newrelic.com/" -ForegroundColor Cyan
    Write-Host "   APM and Services - biblioteca-cqrs" -ForegroundColor Gray
    Write-Host ""
}

# Ejecutar simulación
Start-TrafficSimulation
