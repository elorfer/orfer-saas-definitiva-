# Script PowerShell para verificar costos de AWS
# Requiere: AWS CLI configurado

Write-Host "💰 Verificando costos de AWS..." -ForegroundColor Cyan
Write-Host ""

# Obtener fecha actual y primer día del mes
$currentDate = Get-Date -Format "yyyy-MM-dd"
$monthStart = (Get-Date -Day 1).ToString("yyyy-MM-dd")

Write-Host "📅 Período: $monthStart hasta $currentDate" -ForegroundColor Yellow
Write-Host ""

# Verificar si AWS CLI está instalado
try {
    $null = Get-Command aws -ErrorAction Stop
    Write-Host "✅ AWS CLI encontrado" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS CLI no está instalado" -ForegroundColor Red
    Write-Host "Instala con: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

# Verificar credenciales
try {
    $identity = aws sts get-caller-identity 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Error"
    }
    Write-Host "✅ AWS CLI configurado correctamente" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "❌ AWS CLI no está configurado" -ForegroundColor Red
    Write-Host "Configura con: aws configure" -ForegroundColor Yellow
    exit 1
}

# Obtener costos del mes actual
Write-Host "📊 Costos del mes actual:" -ForegroundColor Cyan
Write-Host ""

$costQuery = @"
{
    "TimePeriod": {
        "Start": "$monthStart",
        "End": "$currentDate"
    },
    "Granularity": "MONTHLY",
    "Metrics": ["BlendedCost"],
    "GroupBy": [
        {
            "Type": "SERVICE",
            "Key": "SERVICE"
        }
    ]
}
"@

$costQuery | Out-File -FilePath "$env:TEMP\aws-cost-query.json" -Encoding utf8

try {
    aws ce get-cost-and-usage `
        --cli-input-json file://$env:TEMP\aws-cost-query.json `
        --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.BlendedCost.Amount]' `
        --output table
    
    Write-Host ""
    Write-Host "💡 Para más detalles, ve a: https://console.aws.amazon.com/cost-management/home" -ForegroundColor Yellow
} catch {
    Write-Host "❌ Error al obtener costos. Verifica tus permisos de AWS." -ForegroundColor Red
    Write-Host "Necesitas permisos: ce:GetCostAndUsage" -ForegroundColor Yellow
}

# Limpiar archivo temporal
Remove-Item "$env:TEMP\aws-cost-query.json" -ErrorAction SilentlyContinue

