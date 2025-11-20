# Script para detener procesos SOLO en el puerto 3001 (Backend)
# Uso: .\scripts\kill-port.ps1
# IMPORTANTE: Solo mata procesos en el puerto 3001, NO todos los procesos de Node.js

$port = 3001

Write-Host "Buscando procesos en el puerto $port (Backend)..."

# Solo liberar el puerto específico sin afectar otros servicios de Node.js
$connections = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
if ($connections) {
    $pids = $connections | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($processId in $pids) {
        try {
            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($process) {
                Write-Host "Deteniendo proceso $processId ($($process.ProcessName)) en puerto $port..."
                Stop-Process -Id $processId -Force -ErrorAction Stop
            }
        } catch {
            Write-Host "No se pudo detener el proceso $processId`: $($_)"
        }
    }
} else {
    Write-Host "El puerto $port ya está libre"
}

Start-Sleep -Seconds 2

# Verificar que el puerto esté libre
$stillInUse = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
if ($stillInUse) {
    Write-Host "⚠️ El puerto $port aún está en uso. Intentando de nuevo..."
    $stillInUse | ForEach-Object { 
        try {
            Stop-Process -Id $_.OwningProcess -Force -ErrorAction Stop
        } catch {
            Write-Host "Error al detener proceso $($_.OwningProcess)`: $($_)"
        }
    }
    Start-Sleep -Seconds 2
}

# Verificación final
$finalCheck = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
if (-not $finalCheck) {
    Write-Host "Puerto $port (Backend) liberado correctamente"
    Write-Host "Otros servicios (Admin Panel puerto 3002, etc.) no fueron afectados"
} else {
    Write-Host "El puerto $port aún está en uso. Procesos activos:"
    $finalCheck | ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        Write-Host "   - PID: $($_.OwningProcess) | Nombre: $($proc.ProcessName) | Estado: $($_.State)"
    }
}

