# 🚀 DEPLOYMENT COMPLETO SIN AWS - CHECKLIST

## ✅ PREPARACIÓN (HOY - 5 min)

### 1. Crear Cuentas
- [ ] Railway: https://railway.app
- [ ] Cloudflare: https://dash.cloudflare.com
- [ ] Vercel: https://vercel.com (si no tienes)
- [ ] Upstash: https://upstash.com

---

## 🌅 DEPLOYMENT (MAÑANA - 3-4 horas)

### HORA 1: Railway (Backend + DB)

#### A. Instalar CLI y Login
```bash
npm install -g @railway/cli
railway login
```

#### B. Deploy Backend
```bash
cd c:\appdefinitiva\apps\backend

# Inicializar proyecto
railway init

# Agregar PostgreSQL
railway add postgresql

# Deploy
railway up

# Ver variables (copiar DATABASE_URL)
railway variables
```

#### C. Configurar Variables de Entorno en Railway
1. Ir a Railway Dashboard → Tu proyecto
2. Settings → Variables
3. Copiar/pegar desde `.env.production.template`
4. **IMPORTANTE:** Solo agregar R2 variables cuando tengas las credenciales de Cloudflare

#### D. Migrar Base de Datos
```bash
# 1. Hacer backup de DB local
pg_dump -h localhost -U postgres struky > backup_local.sql

# 2. Obtener URL de Railway PostgreSQL
railway variables | findstr DATABASE_URL

# 3. Importar a Railway
psql [URL_DE_RAILWAY] < backup_local.sql

# 4. CRITICAL: Ejecutar índices
# Conectar a Railway DB y ejecutar:
railway run npx ts-node scripts/create-indexes.ts
```

---

### HORA 2: Cloudflare R2 (Audio Storage)

#### A. Crear Bucket
1. Ir a https://dash.cloudflare.com
2. R2 Object Storage → Create Bucket
3. Nombre: `struky-audio`
4. Crear

#### B. Obtener Credenciales
1. Manage R2 API Tokens → Create API Token
2. Permisos: Object Read & Write
3. Copiar:
   - Account ID
   - Access Key ID
   - Secret Access Key

#### C. Configurar Dominio Público (Opcional pero recomendado)
1. En tu bucket → Settings → Public Access
2. Enable Public Access
3. Copiar URL pública (ej: `pub-abc123.r2.dev`)

#### D. Agregar Variables a Railway
```env
R2_ACCOUNT_ID=tu_account_id
R2_ACCESS_KEY_ID=tu_key
R2_SECRET_ACCESS_KEY=tu_secret
R2_BUCKET_NAME=struky-audio
```

#### E. Testing Local (Opcional)
```bash
# Crear archivo .env.local con las credenciales de R2
# Ejecutar backend localmente para probar upload
npm run dev
```

---

### HORA 3: Upstash Redis

#### A. Crear Database
1. https://upstash.com → Create Database
2. Nombre: `struky-redis`
3. Región: US East (cercana a Railway)
4. Tier: Free

#### B. Copiar URL
1. Details → Copy REST URL
2. Agregar a Railway:
   ```env
   REDIS_URL=rediss://default:xxx@xxx.upstash.io:6379
   ```

---

### HORA 4: Vercel (Admin + Landing)

#### A. Deploy Landing Page
```bash
cd c:\appdefinitiva\apps\landing

# Instalar Vercel CLI
npm install -g vercel

# Login
vercel login

# Deploy
vercel --prod
```

Variables de entorno en Vercel (landing):
```env
NEXT_PUBLIC_API_URL=https://tu-app.up.railway.app
```

#### B. Deploy Admin Panel
```bash
cd c:\appdefinitiva\apps\admin

# Deploy
vercel --prod
```

Variables de entorno en Vercel (admin):
```env
NEXT_PUBLIC_API_URL=https://tu-app.up.railway.app
NEXT_PUBLIC_WS_URL=wss://tu-app.up.railway.app
```

---

## 🧪 TESTING FINAL 

### 1. Backend Health Check
```bash
curl https://tu-app.up.railway.app/api/health
```

### 2. Test Upload de Audio
1. Ir a Admin Panel
2. Subir una canción de prueba
3. Verificar que se suba a R2
4. Verificar que la URL funcione

### 3. Test Frontend
1. Actualizar `baseUrl` en Flutter app
2. Hot restart
3. Probar login con Facebook
4. Probar reproducción de audio

---

## 🔧 CONFIGURACIÓN FINAL

### Flutter App - Actualizar baseUrl
```dart
// lib/core/services/http_client_service.dart
static const String baseUrl = 'https://tu-app.up.railway.app';
```

### Firebase - Actualizar URLs
1. Firebase Console → Authentication
2. Authorized domains → Agregar:
   - `tu-app.up.railway.app`

### Facebook App - Actualizar Redirect URI
1. Facebook Developers → Tu app
2. Productos → Inicio de sesión con Facebook
3. Redirect URIs → Agregar:
   - `https://struky-5bdb8.firebaseapp.com/__/auth/handler`

---

## 💰 COSTOS MENSUALES

```
Railway (Starter):        $20
Cloudflare R2:            $1-5
Vercel:                   GRATIS
Upstash Redis:            GRATIS
-------------------------------------
TOTAL:                    $21-25/mes
```

---

## 🎉 ¡LISTO!

Tu app estará 100% en producción sin AWS:

✅ Backend: https://tu-app.up.railway.app
✅ Admin: https://admin-struky.vercel.app
✅ Landing: https://struky.vercel.app
✅ Database: Railway PostgreSQL
✅ Audio: Cloudflare R2
✅ CDN: Cloudflare (automático con R2)
✅ Redis: Upstash

**Total invertido: ~$21-25/mes**
**vs AWS: ~$100-150/mes**

**Ahorro: 80-85%** 🚀
