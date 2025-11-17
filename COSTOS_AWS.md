# 💰 Guía de Costos AWS - Vintage Music App

## 📊 Servicios Activos y Costos Estimados

### 1. **ECS (Elastic Container Service)**
- **Qué es**: Contenedores Docker ejecutándose
- **Costo estimado**: ~$15-30/mes
  - Tareas Fargate: ~$0.04/hora por vCPU + ~$0.004/hora por GB RAM
  - Ejemplo: 1 tarea con 0.5 vCPU y 1GB RAM = ~$15/mes

### 2. **RDS PostgreSQL**
- **Qué es**: Base de datos PostgreSQL
- **Costo estimado**: ~$15-50/mes
  - db.t3.micro (2 vCPU, 1GB RAM): ~$15/mes
  - db.t3.small (2 vCPU, 2GB RAM): ~$30/mes
  - Almacenamiento: ~$0.115/GB-mes (primeros 20GB gratis)
  - Backups: ~$0.095/GB-mes

### 3. **ALB (Application Load Balancer)**
- **Qué es**: Balanceador de carga
- **Costo estimado**: ~$16-20/mes
  - Costo fijo: ~$0.0225/hora = ~$16/mes
  - LCU (Load Balancer Capacity Units): ~$0.008/LCU-hora
  - Transferencia de datos: primeros 100GB gratis

### 4. **ECR (Elastic Container Registry)**
- **Qué es**: Almacenamiento de imágenes Docker
- **Costo estimado**: ~$0.10-1/mes
  - Primeros 500MB gratis
  - Después: ~$0.10/GB-mes

### 5. **VPC, Subnets, Security Groups**
- **Costo**: **GRATIS** ✅

### 6. **Data Transfer (Transferencia de Datos)**
- **Costo estimado**: ~$0-10/mes
  - Primeros 100GB/mes gratis
  - Después: ~$0.09/GB (salida a internet)

---

## 💵 **COSTO TOTAL ESTIMADO MENSUAL**

### Escenario Conservador (Bajo Tráfico)
- ECS: $15/mes
- RDS (db.t3.micro): $15/mes
- ALB: $16/mes
- ECR: $0.50/mes
- Data Transfer: $2/mes
- **TOTAL: ~$48-50/mes** 💰

### Escenario Moderado (Tráfico Medio)
- ECS: $25/mes
- RDS (db.t3.small): $30/mes
- ALB: $18/mes
- ECR: $1/mes
- Data Transfer: $5/mes
- **TOTAL: ~$79/mes** 💰

### Escenario Alto Tráfico
- ECS: $50/mes
- RDS (db.t3.medium): $60/mes
- ALB: $25/mes
- ECR: $2/mes
- Data Transfer: $15/mes
- **TOTAL: ~$152/mes** 💰

---

## 🔍 Cómo Monitorear Costos en AWS

### Opción 1: AWS Cost Explorer (Recomendado)
1. Ve a la consola de AWS
2. Busca "Cost Explorer" o "Cost Management"
3. Verás:
   - Costos diarios
   - Costos por servicio
   - Proyecciones de costos
   - Gráficos y reportes

### Opción 2: AWS Billing Dashboard
1. Ve a "Billing Dashboard"
2. Verás:
   - Costo actual del mes
   - Costo estimado del mes
   - Facturación por servicio

### Opción 3: CloudWatch Billing Alarms
Configura alertas cuando los costos superen un umbral.

---

## ⚠️ Alertas de Costos Recomendadas

Configura alertas para:
- **$30/mes**: Alerta temprana
- **$50/mes**: Alerta de atención
- **$100/mes**: Alerta crítica

---

## 💡 Consejos para Reducir Costos

### 1. **RDS - Usar instancias pequeñas**
- db.t3.micro es suficiente para empezar
- Puedes escalar después si es necesario

### 2. **ECS - Optimizar recursos**
- Usa solo los recursos necesarios
- Considera usar Fargate Spot para desarrollo (hasta 70% más barato)

### 3. **ALB - Solo si es necesario**
- Si tienes un solo contenedor, podrías usar un target group directo
- Pero ALB es útil para SSL y routing

### 4. **Reserved Instances (Después de 1 mes)**
- Si sabes que usarás por 1-3 años, puedes ahorrar hasta 75%

### 5. **Monitorear y apagar recursos no usados**
- Apaga instancias de desarrollo cuando no las uses
- Elimina imágenes Docker antiguas de ECR

---

## 📱 Cómo Ver Costos Ahora Mismo

### Desde la Consola AWS:
1. Ve a: https://console.aws.amazon.com/billing/
2. Click en "Cost Explorer"
3. Selecciona el rango de fechas
4. Filtra por servicio para ver detalles

### Desde AWS CLI:
```bash
# Ver costos del mes actual
aws ce get-cost-and-usage \
  --time-period Start=2024-11-01,End=2024-11-13 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

---

## 🎯 Próximos Pasos

1. **Configura alertas de costos** (hoy)
2. **Revisa costos semanalmente** (primer mes)
3. **Optimiza recursos** después de ver uso real
4. **Considera Reserved Instances** si el uso es constante

---

## 📞 Soporte

Si los costos son más altos de lo esperado:
1. Revisa qué servicios están consumiendo más
2. Verifica si hay recursos huérfanos
3. Considera usar AWS Free Tier donde sea posible
4. Contacta soporte AWS para optimización

