# 🚂 Variables de Entorno para Railway

## Instrucciones

1. Ve a tu proyecto en Railway: https://railway.app
2. Selecciona tu servicio **backend**
3. Click en la pestaña **"Variables"**
4. Click en **"New Variable"** y añade cada una de estas:

---

## ✅ Variables R2 (Cloudflare Storage) - REQUERIDAS

```
R2_ACCOUNT_ID
51fedf1a3c0c2c1b24a68e5eef3f076
```

```
R2_ACCESS_KEY_ID
c309ec62e290ab7f30465acc54a662ca
```

```
R2_SECRET_ACCESS_KEY
a47df7b8c119d146069cb3cba515763c20d4ef1b8a2130f5b071c6f92cc83551
```

```
R2_BUCKET_NAME
struky-media
```

```
R2_PUBLIC_DOMAIN
pub-07052fa881994639ae2855365e1b51ed.r2.dev
```

---

## ✅ Variables Existentes (Ya deberías tenerlas)

Verifica que también tengas configuradas estas variables en Railway:

### Base de Datos
- `DATABASE_URL` - Tu URL de PostgreSQL de Railway
- `REDIS_URL` - Tu URL de Redis de Railway (si usas Redis)

### JWT
- `JWT_SECRET` - `vintage_jwt_secret_2024_ultra_secure`
- `JWT_EXPIRES_IN` - `7d`

### RevenueCat
- `REVENUECAT_SECRET_KEY` - `sk_qKQpnKQDievfoBXphBdGIelaCEnrz`

### Resend (Emails)
- `RESEND_API_KEY` - `re_iNvNbLSy_2jbh9SZYVuBVPHLRxaKmZNPi`

### Entorno
- `NODE_ENV` - `production`
- `DATABASE_SSL` - `true` (para Railway debe ser true)

---

## 🔄 Después de agregar las variables

Railway **reiniciará automáticamente** tu backend con las nuevas configuraciones.

Espera 1-2 minutos y luego verifica los logs en Railway:
- ✅ Deberías ver: `🔌 R2 Connection Init: https://51fedf1a3c0c2c1b24a68e5eef3f076.r2.cloudflarestorage.com`
- ✅ Deberías ver: `✅ Storage: Configurado para Cloudflare R2 (Standard Mode)`
- ❌ NO deberías ver: `Error de carga de S3` o `SSL handshake failure`

---

## 📌 Notas Importantes

- **NO subas este archivo a Git** si contiene credenciales reales
- Este archivo es solo para referencia local
- Las credenciales están configuradas para tu cuenta de Cloudflare
- Mantén estas credenciales seguras y nunca las compartas públicamente

---

## 🎯 Siguiente Paso

Una vez configuradas las variables en Railway:
1. Espera a que se complete el deploy
2. Prueba subir una imagen de artista desde el admin
3. Verifica que se suba correctamente a R2
