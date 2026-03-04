# Quick Traffic - Simulación Rápida de Tráfico
# Genera tráfico básico sin configuraciones complejas

param(
    [int]$Requests = 50,
    [string]$BaseUrl = "http://localhost:8089"
)

Write-Host "`n🚀 Quick Traffic Simulation - $Requests requests`n" -ForegroundColor Cyan

$stats = @{
    Success = 0
    Failed = 0
    TotalTime = 0
}

for ($i = 1; $i -le $Requests; $i++) {
    $libroId = "lib-quick-$i"
    $libro = @{
        id = $libroId
        titulo = "Libro $i"
        autor = "Autor $(Get-Random -Minimum 1 -Maximum 10)"
        isbn = "978-$(Get-Random -Minimum 1000000000 -Maximum 9999999999)"
    } | ConvertTo-Json
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Crear libro
        Invoke-RestMethod -Method Post -Uri "$BaseUrl/libros" -Body $libro -ContentType "application/json" | Out-Null
        
        # Consultar libro
        Invoke-RestMethod -Uri "$BaseUrl/libros/$libroId" | Out-Null
        
        $sw.Stop()
        $stats.Success++
        $stats.TotalTime += $sw.ElapsedMilliseconds
        
        Write-Progress -Activity "Generando tráfico" -Status "$i de $Requests" -PercentComplete (($i / $Requests) * 100)
        
    } catch {
        $stats.Failed++
        Write-Host "❌ Error en request $i" -ForegroundColor Red
    }
    
    Start-Sleep -Milliseconds 100
}

Write-Host "`n✅ Completado:" -ForegroundColor Green
Write-Host "   Exitosos: $($stats.Success)" -ForegroundColor White
Write-Host "   Fallidos: $($stats.Failed)" -ForegroundColor Red
Write-Host "   Tiempo promedio: $([math]::Round($stats.TotalTime / $stats.Success, 2))ms`n" -ForegroundColor Yellow
