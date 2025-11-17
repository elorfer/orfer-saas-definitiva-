# Script de EMERGENCIA para reducir costos AWS inmediatamente
# ⚠️ ADVERTENCIA: Esto apagará servicios de producción
# Ejecutar solo si necesitas reducir costos urgentemente

Write-Host "🚨 MODO EMERGENCIA: Reducción de costos AWS" -ForegroundColor Red
Write-Host "⚠️  Esto afectará servicios en producción" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "¿Estás seguro? Escribe 'SI' para continuar"
if ($confirmation -ne "SI") {
    Write-Host "❌ Operación cancelada" -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "📦 Reduciendo servicios ECS..." -ForegroundColor Cyan

# 1. Reducir réplicas de backend a 1
Write-Host "   🔄 Reduciendo réplicas de backend de 2 a 1..." -ForegroundColor Yellow
try {
    $result = aws ecs update-service `
        --cluster backend-prod-cluster `
        --service vintage-music-backend-service `
        --desired-count 1 `
        2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Réplicas reducidas a 1" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Error: $result" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  No se pudo reducir réplicas: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📊 Verificando otros servicios..." -ForegroundColor Cyan

# 2. Verificar instancias EC2
Write-Host "   🖥️  Instancias EC2:" -ForegroundColor Yellow
try {
    $instances = aws ec2 describe-instances `
        --query 'Reservations[*].Instances[?State.Name==`running`].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' `
        --output table `
        2>&1
    
    if ($instances -and $instances.Length -gt 0) {
        Write-Host $instances
        Write-Host ""
        Write-Host "   ⚠️  ACCIÓN REQUERIDA: Apaga instancias EC2 innecesarias desde la consola:" -ForegroundColor Red
        Write-Host "      https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Instances:" -ForegroundColor White
    } else {
        Write-Host "   ✅ No se encontraron instancias EC2 corriendo" -ForegroundColor Green
    }
} catch {
    Write-Host "   ⚠️  Error al verificar instancias EC2" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "💡 RECOMENDACIONES ADICIONALES:" -ForegroundColor Cyan
Write-Host "   1. Apaga Prometheus/Grafana si no los usas: docker-compose -f docker-compose.prod.yml stop prometheus grafana" -ForegroundColor White
Write-Host "   2. Verifica RDS: Considera pausarlo fuera de horarios de producción" -ForegroundColor White
Write-Host "   3. Revisa S3: Elimina buckets/objetos innecesarios" -ForegroundColor White
Write-Host ""
Write-Host "💰 Para monitorear costos:" -ForegroundColor Cyan
Write-Host "   https://console.aws.amazon.com/cost-management/home" -ForegroundColor White







