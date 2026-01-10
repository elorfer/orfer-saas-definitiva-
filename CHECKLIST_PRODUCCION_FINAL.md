# ✅ CHECKLIST FINAL PARA PRODUCCIÓN - Struky

## 🎯 **STATUS ACTUAL:**
- ✅ Login con email/password funcionando
- ✅ Login con Google funcionando
- ✅ Login con Facebook funcionando
- ✅ Recuperación de contraseña funcionando (modo desarrollo)
- ✅ Backend funcionando con Railway stack (sin AWS)
- ✅ Frontend compilando correctamente
- ✅ Índices de DB preparados (`create-indexes.ts`)

---

## 🔥 **PENDIENTES CRÍTICOS ANTES DE PRODUCCIÓN:**

### **1. Firebase - Emails de Recuperación de Contraseña** ⏱️ 5 min

#### **A. Obtener credenciales:**
1. https://console.firebase.google.com
2. Proyecto: **struky-5bdb8**
3. ⚙️ Settings → **Service accounts**
4. Click **"Generate new private key"**
5. Descargar JSON

#### **B. Agregar al `.env` del backend:**
```env
FIREBASE_PROJECT_ID=struky-5bdb8
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@struky-5bdb8.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEv...==\n-----END PRIVATE KEY-----\n"
```

📄 **Ver:** `.env.firebase.template` para instrucciones detalladas

#### **C. Verificar:**
```bash
# Reiniciar backend
cd apps/backend
npm run dev

# Deberías ver en los logs:
# ✅ Firebase Admin SDK initialized successfully
# (en lugar de ⚠️ Firebase credentials not found)
```

---

### **2. Base de Datos - Crear Índices** ⏱️ 2 min

**IMPORTANTE:** Ejecutar DESPUÉS de migrar la DB a Railway

```bash
cd apps/backend

# Conectar a Railway DB y ejecutar:
railway run npx ts-node scripts/create-indexes.ts

# Deberías ver:
# ✅ Índice creado exitosamente
# ✅ Índice creado exitosamente
# ✅ Todos los índices han sido creados/verificados
```

**¿Por qué?** Optimiza consultas del algoritmo de recomendaciones (5x más rápido)

---

### **3. Variables de Entorno - Railway** ⏱️ 10 min

#### **A. Backend (Railway):**
```env
NODE_ENV=production
DATABASE_URL=[Auto-generada por Railway ✅]
JWT_SECRET=cambia_esto_por_un_secret_seguro_de_32_caracteres

# Facebook Login
FACEBOOK_APP_ID=1209364637258569
FACEBOOK_APP_SECRET=36cd4bb61c0474467f232e0130a6e9bd

# Firebase (copiar del JSON descargado)
FIREBASE_PROJECT_ID=struky-5bdb8
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@struky-5bdb8.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# Cloudflare R2 (Storage de audio)
R2_ACCOUNT_ID=tu_account_id
R2_ACCESS_KEY_ID=tu_key
R2_SECRET_ACCESS_KEY=tu_secret
R2_BUCKET_NAME=struky-audio

# Redis (Upstash)
REDIS_URL=rediss://default:xxx@xxx.upstash.io:6379

# URLs
FRONTEND_URL=https://tuapp.vercel.app
ADMIN_URL=https://admin-tuapp.vercel.app
```

#### **B. Frontend Flutter:**
Actualizar `baseUrl` en:
```dart
// lib/core/services/http_client_service.dart
static const String baseUrl = 'https://tu-app.up.railway.app';
```

#### **C. Admin Panel (Vercel):**
```env
NEXT_PUBLIC_API_URL=https://tu-app.up.railway.app
NEXT_PUBLIC_WS_URL=wss://tu-app.up.railway.app
```

#### **D. Landing Page (Vercel):**
```env
NEXT_PUBLIC_API_URL=https://tu-app.up.railway.app
```

---

### **4. Facebook App - Configuración Final** ⏱️ 3 min

#### **A. Verificar Redirect URI:**
1. Facebook Developers → Tu app (ID: 1209364637258569)
2. Productos → **Inicio de sesión con Facebook**
3. **Valid OAuth Redirect URIs:**
   ```
   https://struky-5bdb8.firebaseapp.com/__/auth/handler
   ```
4. **Guardar cambios**

#### **B. Verificar Roles:**
- Tu cuenta debe estar como **Administrador** o **Desarrollador**
- Mantener en modo **"Desarrollo"** hasta que publiques en Play Store

---

### **5. Cloudflare R2 - Storage de Audio** ⏱️ 15 min

#### **A. Crear bucket:**
1. https://dash.cloudflare.com → R2
2. **Create Bucket:** `struky-audio`

#### **B. Generar credenciales:**
1. **Manage R2 API Tokens**
2. **Create API Token**
3. Permisos: **Object Read & Write**
4. Copiar:
   - Account ID
   - Access Key ID
   - Secret Access Key

#### **C. Agregar a Railway:**
```env
R2_ACCOUNT_ID=xxx
R2_ACCESS_KEY_ID=xxx
R2_SECRET_ACCESS_KEY=xxx
R2_BUCKET_NAME=struky-audio
```

📄 **Ya actualizado:** `backend/src/modules/upload/s3.service.ts` detecta automáticamente R2 vs S3

---

### **6. Upstash Redis** ⏱️ 5 min

1. https://upstash.com → **Create Database**
2. Nombre: `struky-redis`
3. Región: **US East** (cercana a Railway)
4. Tier: **Free**
5. Copiar **REDIS_URL**
6. Agregar a Railway

---

## 📋 **ORDEN RECOMENDADO DE DEPLOYMENT:**

```
DÍA 1: SETUP SERVICIOS
├─ 1. Crear cuenta Railway (si no tienes)
├─ 2. Crear cuenta Cloudflare (si no tienes)
├─ 3. Crear cuenta Upstash (si no tienes)
└─ 4. Obtener credenciales Firebase ← HACER AHORA

DÍA 2: DEPLOY BACKEND
├─ 1. Crear proyecto Railway
├─ 2. Agregar PostgreSQL
├─ 3. Configurar todas las variables
├─ 4. Deploy backend
├─ 5. Migrar base de datos
└─ 6. ⚠️ EJECUTAR create-indexes.ts

DÍA 3: DEPLOY FRONTEND
├─ 1. Actualizar baseUrl en Flutter
├─ 2. Deploy admin a Vercel
├─ 3. Deploy landing a Vercel
└─ 4. Testing completo
```

---

## 🧪 **TESTING PRE-PRODUCCIÓN:**

### **Checklist de pruebas:**
- [ ] Login con email/password
- [ ] Login con Google
- [ ] Login con Facebook
- [ ] Recuperación de contraseña (con email real)
- [ ] Reproducción de audio
- [ ] Algoritmo de recomendaciones
- [ ] Subida de canciones (admin)
- [ ] Sistema de anuncios

---

## 📚 **DOCUMENTACIÓN CREADA:**

- ✅ `DEPLOYMENT_SIN_AWS.md` - Guía completa deployment Railway + R2
- ✅ `FIREBASE_PASSWORD_RESET.md` - Setup emails recuperación
- ✅ `.env.firebase.template` - Template Firebase credentials
- ✅ `.env.production.template` - Template variables producción
- ✅ `PLAN_PRODUCCION_2026.md` - Plan completo (ya existía)

---

## 💰 **COSTOS MENSUALES ESTIMADOS:**

```
Railway (Backend + DB):    $20-40
Cloudflare R2:             $1-5
Vercel:                    GRATIS
Upstash Redis:             GRATIS
Firebase Auth:             GRATIS
──────────────────────────────────
TOTAL:                     $21-45/mes

vs AWS Full Stack:         $100-150/mes
AHORRO:                    ~70%
```

---

## ⚠️ **RECORDATORIOS IMPORTANTES:**

1. **Firebase PRIVATE_KEY:**
   - Debe tener `\n` literales (no saltos de línea reales)
   - Debe estar entre comillas dobles

2. **Índices de DB:**
   - ⚠️ NO olvidar ejecutar después de migrar DB
   - Crítico para performance

3. **Facebook App:**
   - Mantener en Development hasta publicar en Play Store
   - Resetear App Secret después de configurar (seguridad)

4. **Testing:**
   - Probar TODO antes de dar acceso a usuarios
   - Usar datos de prueba primero

---

## ✅ **PRÓXIMO PASO INMEDIATO:**

### **🔥 HACER AHORA (antes de dormir):**

1. **Obtener Firebase credentials:**
   - https://console.firebase.google.com
   - Generar Service Account Key
   - Descargar JSON

2. **Agregar al `.env` del backend local:**
   - Copiar valores del JSON
   - Agregar las 3 variables
   - Reiniciar backend
   - Ver que diga "Firebase initialized successfully"

3. **Probar recuperación con email real:**
   - Usar tu email personal
   - Verificar que llegue el email de Firebase
   - Confirmar que el link funciona

**Tiempo estimado:** 10 minutos  
**Resultado:** Email de recuperación funcionando al 100%

---

¿Listo para empezar? Te ayudo paso a paso. 🚀
