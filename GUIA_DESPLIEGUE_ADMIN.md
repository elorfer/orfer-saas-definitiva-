# 🚀 Guía Completa: Desplegar Admin Panel a AWS

## 📋 Análisis del Admin Panel

### **Tecnología:**
- **Framework**: Next.js 14 (React)
- **Lenguaje**: TypeScript
- **Autenticación**: NextAuth.js
- **UI**: Tailwind CSS + Headless UI
- **Estado**: React Query

### **Estructura:**
```
apps/admin/
├── src/
│   ├── app/              # App Router de Next.js
│   ├── components/       # Componentes React
│   ├── hooks/           # Custom hooks
│   ├── lib/             # Utilidades (API, auth)
│   └── config/          # Configuración
├── Dockerfile           # Multi-stage build
├── next.config.js       # Configuración Next.js
└── package.json        # Dependencias
```

### **Características:**
- ✅ SSR (Server-Side Rendering)
- ✅ API Routes (NextAuth)
- ✅ Static Assets
- ✅ Dockerizado
- ✅ Configuración por entornos

---

## 🎯 Estado Actual

### **¿Dónde está ahora?**
- ❌ **NO está desplegado en AWS**
- ✅ Está configurado en `docker-compose.prod.yml` (pero no se usa)
- ✅ Solo el **backend** está en AWS ECS
- ✅ El admin corre **localmente** o en Docker local

### **¿Debe subirse a AWS?**
**✅ SÍ, es recomendable** porque:
1. Acceso desde cualquier lugar
2. Mismo entorno que el backend
3. Mejor seguridad
4. Escalabilidad
5. Monitoreo centralizado

---

## 📦 Opciones de Despliegue

### **Opción 1: AWS ECS (Recomendado)**
- ✅ Mismo stack que el backend
- ✅ Fácil de mantener
- ✅ Costo: ~$15-20/mes adicional

### **Opción 2: Vercel/Netlify**
- ✅ Gratis para proyectos pequeños
- ✅ Optimizado para Next.js
- ⚠️ Requiere configuración adicional

### **Opción 3: EC2 + Docker**
- ✅ Control total
- ⚠️ Más complejo de mantener

**Recomendación: Opción 1 (AWS ECS)** - Mismo stack que el backend

---

## 🚀 Guía Paso a Paso: Desplegar a AWS ECS

### **Paso 1: Construir la Imagen Docker**

```bash
cd apps/admin

# Construir imagen localmente para probar
docker build -t vintage-music-admin:latest .

# Probar localmente
docker run -p 3002:3000 \
  -e NODE_ENV=production \
  -e NEXT_PUBLIC_API_URL=http://backend-alb-1038609925.us-east-1.elb.amazonaws.com \
  vintage-music-admin:latest
```

### **Paso 2: Subir Imagen a ECR**

```bash
# 1. Crear repositorio ECR (si no existe)
aws ecr create-repository \
  --repository-name vintage-music-admin \
  --region us-east-1

# 2. Obtener URL del repositorio
aws ecr describe-repositories \
  --repository-names vintage-music-admin \
  --region us-east-1 \
  --query 'repositories[0].repositoryUri' \
  --output text

# 3. Autenticar Docker con ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# 4. Taggear la imagen
docker tag vintage-music-admin:latest \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/vintage-music-admin:latest

# 5. Subir la imagen
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/vintage-music-admin:latest
```

### **Paso 3: Crear Task Definition**

Crear archivo `admin-task-definition.json`:

```json
{
  "family": "admin-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "admin",
      "image": "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/vintage-music-admin:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "NEXT_PUBLIC_API_URL",
          "value": "http://backend-alb-1038609925.us-east-1.elb.amazonaws.com"
        },
        {
          "name": "NEXTAUTH_URL",
          "value": "http://admin-alb-XXXXX.us-east-1.elb.amazonaws.com"
        },
        {
          "name": "NEXTAUTH_SECRET",
          "value": "tu-secret-key-aqui"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/admin-task",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3
      }
    }
  ]
}
```

### **Paso 4: Registrar Task Definition**

```bash
aws ecs register-task-definition \
  --cli-input-json file://admin-task-definition.json \
  --region us-east-1
```

### **Paso 5: Crear Load Balancer para Admin (Opcional)**

Si quieres un ALB separado:

```bash
# Crear ALB para admin
aws elbv2 create-load-balancer \
  --name admin-alb \
  --subnets subnet-0afad41238df3d96d subnet-0749c393dceeada5c \
  --security-groups sg-016ae943f28417388 \
  --region us-east-1
```

**O usar el mismo ALB del backend** (más económico):
- Agregar un nuevo target group
- Agregar una nueva regla de routing

### **Paso 6: Crear Servicio ECS**

```bash
aws ecs create-service \
  --cluster backend-prod-cluster \
  --service-name admin-service \
  --task-definition admin-task:1 \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-0afad41238df3d96d,subnet-0749c393dceeada5c],securityGroups=[sg-016ae943f28417388],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=<TARGET_GROUP_ARN>,containerName=admin,containerPort=3000" \
  --region us-east-1
```

---

## 🔧 Configuración Necesaria

### **Variables de Entorno Requeridas:**

```env
NODE_ENV=production
NEXT_PUBLIC_API_URL=http://backend-alb-1038609925.us-east-1.elb.amazonaws.com
NEXTAUTH_URL=http://admin-alb-XXXXX.us-east-1.elb.amazonaws.com
NEXTAUTH_SECRET=tu-secret-key-muy-seguro-aqui
```

### **Secrets a Configurar:**

1. **NEXTAUTH_SECRET**: Generar con:
   ```bash
   openssl rand -base64 32
   ```

2. **NEXTAUTH_URL**: URL pública del admin panel

---

## 📝 Scripts Automatizados

### **Script: build-and-push-admin.sh**

```bash
#!/bin/bash

# Configuración
REGION="us-east-1"
REPO_NAME="vintage-music-admin"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_TAG="latest"

echo "🔨 Construyendo imagen Docker..."
cd apps/admin
docker build -t ${REPO_NAME}:${IMAGE_TAG} .

echo "🏷️  Taggeando imagen..."
docker tag ${REPO_NAME}:${IMAGE_TAG} \
  ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}

echo "🔐 Autenticando con ECR..."
aws ecr get-login-password --region ${REGION} | \
  docker login --username AWS --password-stdin \
  ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

echo "📤 Subiendo imagen a ECR..."
docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}

echo "✅ Imagen subida exitosamente!"
```

### **Script: deploy-admin.ps1**

```powershell
# Script PowerShell para desplegar admin a AWS ECS

$REGION = "us-east-1"
$CLUSTER = "backend-prod-cluster"
$SERVICE = "admin-service"
$TASK_DEFINITION = "admin-task"

Write-Host "🚀 Desplegando admin panel..." -ForegroundColor Cyan

# Actualizar servicio
aws ecs update-service `
  --cluster $CLUSTER `
  --service $SERVICE `
  --force-new-deployment `
  --region $REGION

Write-Host "✅ Servicio actualizado. Esperando despliegue..." -ForegroundColor Green

# Esperar a que el servicio esté estable
aws ecs wait services-stable `
  --cluster $CLUSTER `
  --services $SERVICE `
  --region $REGION

Write-Host "✅ Despliegue completado!" -ForegroundColor Green
```

---

## 🔍 Verificación Post-Despliegue

### **1. Verificar Servicio**

```bash
aws ecs describe-services \
  --cluster backend-prod-cluster \
  --services admin-service \
  --region us-east-1
```

### **2. Ver Logs**

```bash
aws logs tail /ecs/admin-task --follow --region us-east-1
```

### **3. Probar Endpoint**

```bash
curl http://admin-alb-XXXXX.us-east-1.elb.amazonaws.com
```

---

## 💰 Costos Estimados

### **Con ALB Separado:**
- ECS Fargate: ~$15/mes
- ALB: ~$16/mes
- **Total: ~$31/mes**

### **Compartiendo ALB con Backend:**
- ECS Fargate: ~$15/mes
- ALB: $0 (ya pagado)
- **Total: ~$15/mes** ✅ **Recomendado**

---

## 🎯 Resumen de Pasos

1. ✅ Construir imagen Docker
2. ✅ Crear repositorio ECR
3. ✅ Subir imagen a ECR
4. ✅ Crear Task Definition
5. ✅ Crear Servicio ECS
6. ✅ Configurar Load Balancer (o usar el existente)
7. ✅ Configurar variables de entorno
8. ✅ Verificar despliegue

---

## ⚠️ Consideraciones Importantes

1. **NextAuth URL**: Debe ser la URL pública del admin
2. **API URL**: Debe apuntar al backend en AWS
3. **Secrets**: Nunca hardcodear, usar variables de entorno
4. **Health Check**: Next.js necesita endpoint `/api/health` o similar
5. **CORS**: El backend debe permitir el dominio del admin

---

## 🆘 Troubleshooting

### **Error: "Cannot connect to backend"**
- Verificar `NEXT_PUBLIC_API_URL`
- Verificar CORS en backend
- Verificar security groups

### **Error: "NextAuth configuration invalid"**
- Verificar `NEXTAUTH_URL` y `NEXTAUTH_SECRET`
- Asegurar que la URL sea accesible públicamente

### **Error: "Task failed to start"**
- Revisar logs en CloudWatch
- Verificar variables de entorno
- Verificar permisos IAM

---

**¿Listo para desplegar? Te guío paso a paso cuando estés listo.** 🚀

