# 🛡️ Guía Completa: Asegurar que Todo Esté Bien y Controlar Costos

## ✅ Estado Actual de tus Recursos

### Recursos Activos Verificados:
- ✅ **ECS Cluster**: `backend-prod-cluster` (activo)
- ✅ **RDS PostgreSQL**: `vintage-prod-db` (db.t3.micro - disponible)
- ✅ **ALB**: `backend-alb` (activo)
- ✅ **Tareas ECS**: 1 tarea ejecutándose

### Costo Actual:
- **Mes actual (Nov 1-13)**: ~$3 USD
- **Proyección mensual**: ~$6-10 USD

---

## 🔔 Paso 1: Configurar Alertas de Costos (CRÍTICO)

### Opción A: Desde la Consola AWS (Recomendado)

1. **Activar Billing Alerts:**
   - Ve a: https://console.aws.amazon.com/billing/
   - Click en "Billing preferences"
   - Activa "Receive Billing Alerts"
   - Guarda cambios

2. **Crear Alarmas de Costos:**
   - Ve a: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:
   - Click en "Create alarm"
   - Selecciona "Billing" metric
   - Configura alarmas:
     - **Alerta 1**: $10 USD (alerta temprana)
     - **Alerta 2**: $25 USD (atención)
     - **Alerta 3**: $50 USD (crítico)

3. **Configurar Notificaciones:**
   - Crea un tema SNS: https://console.aws.amazon.com/sns/v3/home?region=us-east-1#/topics
   - Agrega tu email como suscriptor
   - Confirma el email cuando llegue

### Opción B: Usando el Script

```powershell
# Ejecuta el script de configuración de alertas
powershell -ExecutionPolicy Bypass -File "scripts\setup-cost-alerts.sh"
```

**IMPORTANTE**: Después de ejecutar el script, debes:
1. Ir a SNS y suscribirte al tema con tu email
2. Confirmar la suscripción cuando llegue el email

---

## 📊 Paso 2: Configurar Budgets (Límites de Gasto)

### Desde la Consola:

1. Ve a: https://console.aws.amazon.com/billing/home#/budgets
2. Click en "Create budget"
3. Selecciona "Cost budget"
4. Configura:
   - **Presupuesto mensual**: $30 USD
   - **Alertas**: 
     - 80% del presupuesto ($24 USD)
     - 100% del presupuesto ($30 USD)
   - **Contactos**: Tu email

**Esto te avisará ANTES de que se disparen los costos**

---

## 🔍 Paso 3: Monitoreo Regular

### Script de Verificación de Salud

Ejecuta semanalmente:

```powershell
powershell -ExecutionPolicy Bypass -File "scripts\check-aws-health.ps1"
```

Este script verifica:
- ✅ Estado de ECS
- ✅ Estado de RDS
- ✅ Estado de ALB
- ✅ Costos actuales

### Verificación Manual Rápida

**Costos:**
```bash
aws ce get-cost-and-usage --time-period Start=2025-11-01,End=2025-11-13 --granularity MONTHLY --metrics BlendedCost --query 'ResultsByTime[0].Total.BlendedCost' --output text
```

**Recursos:**
- ECS: https://console.aws.amazon.com/ecs/v2/clusters
- RDS: https://console.aws.amazon.com/rds/home
- ALB: https://console.aws.amazon.com/ec2/v2/home#LoadBalancers:
- Costos: https://console.aws.amazon.com/cost-management/home

---

## 🚨 Señales de Alerta

### Costos Anormales:
- ⚠️ **> $25 USD/mes** sin aumento de tráfico
- ⚠️ **> $50 USD/mes** sin justificación
- ⚠️ **Incremento súbito** de un día para otro

### Recursos Problemáticos:
- ❌ RDS en estado diferente a "available"
- ❌ ALB en estado diferente a "active"
- ❌ Tareas ECS fallando constantemente
- ❌ Múltiples instancias RDS (debería haber solo 1)

---

## 💡 Prevención de Costos Altos

### 1. **Revisar Recursos Huérfanos**
```bash
# Ver todas las instancias EC2 (no deberías tener ninguna si usas Fargate)
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' --output table

# Ver todos los volúmenes EBS
aws ec2 describe-volumes --query 'Volumes[*].[VolumeId,State,Size]' --output table
```

### 2. **Limpiar Imágenes Docker Antiguas**
```bash
# Ver imágenes en ECR
aws ecr describe-images --repository-name vintage-music-backend --query 'imageDetails[*].[imageTags[0],imagePushedAt]' --output table

# Eliminar imágenes antiguas (mantén solo las últimas 5)
```

### 3. **Optimizar Tamaño de RDS**
- Tu instancia actual: `db.t3.micro` ✅ (perfecta para empezar)
- No subas de tamaño a menos que sea necesario
- Monitorea uso de CPU y memoria en CloudWatch

### 4. **Monitorear Data Transfer**
- Primeros 100GB/mes son gratis
- Después: ~$0.09/GB
- Revisa en Cost Explorer qué servicios consumen más transferencia

---

## 📅 Checklist Semanal

- [ ] Revisar costos en Cost Explorer
- [ ] Verificar estado de servicios (ECS, RDS, ALB)
- [ ] Revisar alarmas de CloudWatch
- [ ] Verificar que no haya recursos huérfanos
- [ ] Revisar logs de errores en CloudWatch

---

## 📅 Checklist Mensual

- [ ] Revisar factura completa
- [ ] Analizar tendencias de costos
- [ ] Optimizar recursos si es necesario
- [ ] Actualizar budgets si el uso cambia
- [ ] Revisar y limpiar recursos no usados

---

## 🆘 Qué Hacer si los Costos se Disparan

### Paso 1: Identificar el Culpable
1. Ve a Cost Explorer
2. Filtra por servicio
3. Identifica qué servicio está consumiendo más

### Paso 2: Revisar Recursos
1. Verifica si hay instancias adicionales
2. Revisa si hay volúmenes huérfanos
3. Verifica transferencia de datos

### Paso 3: Acción Inmediata
- **Si es RDS**: Verifica tamaño de instancia
- **Si es ECS**: Verifica número de tareas
- **Si es Data Transfer**: Revisa qué está generando tráfico
- **Si es ALB**: Verifica si hay múltiples load balancers

### Paso 4: Contactar Soporte
Si no encuentras la causa:
- AWS Support: https://console.aws.amazon.com/support/home
- Pueden ayudarte a identificar recursos costosos

---

## 📞 Enlaces Útiles

- **Cost Explorer**: https://console.aws.amazon.com/cost-management/home#/cost-explorer
- **Billing Dashboard**: https://console.aws.amazon.com/billing/home
- **Budgets**: https://console.aws.amazon.com/billing/home#/budgets
- **CloudWatch Alarms**: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:
- **ECS Clusters**: https://console.aws.amazon.com/ecs/v2/clusters
- **RDS Instances**: https://console.aws.amazon.com/rds/home
- **ALB**: https://console.aws.amazon.com/ec2/v2/home#LoadBalancers:

---

## ✅ Resumen: Lo que Tienes Configurado

### Recursos Optimizados:
- ✅ RDS: db.t3.micro (instancia pequeña y económica)
- ✅ ECS: 1 tarea (suficiente para empezar)
- ✅ ALB: 1 load balancer (necesario)

### Costos Esperados:
- **Mensual normal**: $6-10 USD
- **Con crecimiento moderado**: $15-25 USD
- **Con alto tráfico**: $30-50 USD

### Protecciones:
- ⚠️ **PENDIENTE**: Configurar alertas de costos
- ⚠️ **PENDIENTE**: Configurar budgets
- ✅ Scripts de monitoreo creados

---

## 🎯 Acción Inmediata Recomendada

**HOY MISMO:**
1. ✅ Configura alertas de costos (15 minutos)
2. ✅ Configura un budget de $30 USD/mes (10 minutos)
3. ✅ Suscríbete a notificaciones SNS (5 minutos)

**ESTA SEMANA:**
1. Ejecuta el script de verificación de salud
2. Revisa costos en Cost Explorer
3. Familiarízate con los dashboards

**ESTE MES:**
1. Revisa costos semanalmente
2. Ajusta budgets si es necesario
3. Optimiza recursos basado en uso real

---

**Con estas configuraciones, estarás protegido contra costos inesperados y tendrás visibilidad completa de tu infraestructura.** 🛡️

