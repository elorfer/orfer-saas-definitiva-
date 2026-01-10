# 🚀 DEPLOYMENT A RAILWAY - GUÍA DEFINITIVA

## ✅ **PRE-REQUISITOS COMPLETADOS:**

- ✅ Backend funcional
- ✅ Dockerfile configurado
- ✅ Scripts de espera listos
- ✅ Variables de entorno identificadas

---

## 📋 **PASO 1: Crear cuenta en Railway**

1. Ve a https://railway.app
2. Click en "Start a New Project"
3. Conecta tu cuenta de GitHub

---

## 📦 **PASO 2: Configurar PostgreSQL**

1. En Railway, click en "+ New"
2. Selecciona "Database" → "PostgreSQL"
3. Railway creará automáticamente:
   - `DATABASE_URL` (se auto-configura)
   - Puerto 5432
   - Usuario y contraseña

**✅ No necesitas hacer nada más, Railway lo maneja todo.**

---

## 📦 **PASO 3: Configurar Redis (Opcional - pero recomendado)**

1. Click en "+ New"
2. Selecciona "Database" → "Redis"
3. Railway creará automáticamente:
   - `REDIS_URL` (se auto-configura)

---

## 🚂 **PASO 4: Deployar Backend**

### **Opción A: Desde GitHub (Recomendado)**

1. Sube tu código a GitHub:
   ```bash
   cd c:\appdefinitiva
   git add .
   git commit -m "Ready for production"
   git push
   ```

2. En Railway:
   - Click "+ New"
   - "Deploy from GitHub repo"
   - Selecciona tu repositorio
   - Root directory: `apps/backend`

3. Railway detectará automáticamente el Dockerfile y deployará

### **Opción B: Railway CLI (Más rápido)**

```powershell
# Instalar Railway CLI
npm install -g @railway/cli

# Login
railway login

# Link al proyecto
cd c:\appdefinitiva\apps\backend
railway link

# Deploy
railway up
```

---

## ⚙️ **PASO 5: Configurar Variables de Entorno**

En Railway, ve a tu servicio de backend → "Variables":

### **📋 Variables CRÍTICAS:**

```env
# JWT
JWT_SECRET=vintage_jwt_secret_2024_ultra_secure_CHANGE_IN_PROD
JWT_EXPIRES_IN=7d

# Resend (Emails)
RESEND_API_KEY=re_iNvNbLSy_2jbh9SZYVuBVPHLRxaKmZNPi

# Firebase (Auth)
FIREBASE_PROJECT_ID=struky-5bdb8
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@struky-5bdb8.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvQIBA...\n-----END PRIVATE KEY-----"

# URLs
FRONTEND_URL=https://tudominio.com
NODE_ENV=production

# AWS S3 (si lo usas)
AWS_ACCESS_KEY_ID=tu_access_key
AWS_SECRET_ACCESS_KEY=tu_secret_key
AWS_REGION=us-east-1
AWS_S3_BUCKET=vintage-music-storage

# CloudFront (si lo usas)
CLOUDFRONT_DOMAIN=tu_dominio.cloudfront.net
```

### **⚠️ IMPORTANTE:**

- `DATABASE_URL` → **Railway lo crea automáticamente**, NO lo agregues manualmente
- `REDIS_URL` → **Railway lo crea automáticamente**, NO lo agregues manualmente
- `FIREBASE_PRIVATE_KEY` → **DEBE estar entre comillas** y con `\n` escapados

---

## 🔗 **PASO 6: Conectar Dominio (Opcional)**

1. En Railway, ve a tu servicio → "Settings"
2. Scroll hasta "Domains"
3. Click "Generate Domain" (gratis: `tu-app.up.railway.app`)
4. O conecta tu dominio personalizado (struky.com)

### **Para dominio personalizado:**

1. En Railway: "Add Custom Domain"
2. Ingresa: `api.struky.com`
3. Railway te dará un CNAME
4. En tu proveedor de dominio (Vercel/Namecheap/etc):
   - Tipo: CNAME
   - Nombre: api
   - Valor: [el que te dio Railway]

---

## 🧪 **PASO 7: Verificar Deployment**

### **Railway te dará una URL:**
```
https://backend-production-xxxx.up.railway.app
```

### **Probar endpoints:**

```bash
# Health check
curl https://tu-url.railway.app/health

# API docs
https://tu-url.railway.app/api/docs
```

---

## 📱 **PASO 8: Actualizar Flutter App**

En `api_config.dart`:

```dart
static const String baseUrl = kDebugMode 
  ? 'http://localhost:3001/api/v1'
  : 'https://api.struky.com/api/v1';  // O tu URL de Railway
```

Rebuild la app:

```bash
flutter clean
flutter build apk --release
```

---

## 🔐 **PASO 9: SEGURIDAD**

### **Cambios CRÍTICOS antes de producción:**

1. **JWT_SECRET:** Genera uno nuevo:
   ```bash
   node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
   ```

2. **CORS:** Verifica en `main.ts` que solo permites tu dominio:
   ```typescript
   app.enableCors({
     origin: ['https://tudominio.com', 'https://api.struky.com'],
     credentials: true,
   });
   ```

3. **Rate Limiting:** Ya está configurado en el backend

---

## 💰 **COSTOS ESTIMADOS:**

### **Railway:**
- **Plan Hobby:** $5/mes (incluye $5 de créditos)
- PostgreSQL: Incluido
- Redis: Incluido
- 500 horas de ejecución/mes
- **Suficiente para:** Startup pequeña (< 10k usuarios)

### **Alternativas si necesitas más:**

| Servicio | Costo | Límites |
|----------|-------|---------|
| **Railway** | $5/mes | 500h, PostgreSQL, Redis |
| **Render** | $7/mes | PostgreSQL incluido |
| **Fly.io** | $0-$5/mes | PostgreSQL separado ($1/GB) |

---

## 🎯 **TROUBLESHOOTING:**

### **"Build failed"**
- Verifica que `package.json` tenga `build` script
- Verifica que `Dockerfile` esté en la raíz de `apps/backend`

### **"Can't connect to database"**
- Railway auto-configura `DATABASE_URL`
- Verifica que tu app use `process.env.DATABASE_URL`

### **"Module not found"**
- Verifica que `package-lock.json` esté en el repo
- Railway usa `npm ci` para instalar dependencias

### **"Firebase error"**
- Verifica que `FIREBASE_PRIVATE_KEY` tenga comillas
- Verifica que los `\n` estén escapados correctamente

---

## ✅ **CHECKLIST FINAL:**

- [ ] Cuenta Railway creada
- [ ] PostgreSQL configurado
- [ ] Redis configurado (opcional)
- [ ] Código en GitHub
- [ ] Backend deployado
- [ ] Variables de entorno configuradas
- [ ] Dominio conectado
- [ ] Health check funcionando (/health)
- [ ] API docs accesibles (/api/docs)
- [ ] Flutter app actualizada con nueva URL
- [ ] JWT_SECRET cambiado
- [ ] CORS configurado
- [ ] Pruebas de endpoints críticos

---

## 🚀 **DEPLOYMENT EN 5 PASOS:**

```bash
# 1. Instalar Railway CLI
npm install -g @railway/cli

# 2. Login
railway login

# 3. Ir al backend
cd c:\appdefinitiva\apps\backend

# 4. Crear proyecto
railway init

# 5. Deploy
railway up
```

**¡Y LISTO!** 🎉

---

## 📞 **SOPORTE:**

- Railway Docs: https://docs.railway.app
- Railway Discord: https://discord.gg/railway
- Status: https://status.railway.app

---

**¿Listo para deployar?** 🚀
