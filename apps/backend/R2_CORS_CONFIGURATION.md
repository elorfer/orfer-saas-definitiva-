# 🌐 CONFIGURACIÓN CORS PARA CLOUDFLARE R2

**IMPORTANTE**: Necesitas configurar CORS en tu bucket R2 para que los uploads funcionen.

## 📝 Pasos:

1. Ve a **Cloudflare Dashboard** → **R2**
2. Selecciona tu bucket: `struky-media`
3. Ve a **Settings** → **CORS Policy**
4. Click **Add CORS Policy**
5. Pega esta configuración:

```json
[
  {
    "AllowedOrigins": [
      "https://struky-admin.vercel.app",
      "http://localhost:3000",
      "http://localhost:3001"
    ],
    "AllowedMethods": [
      "GET",
      "PUT",
      "POST",
      "DELETE",
      "HEAD"
    ],
    "AllowedHeaders": [
      "*"
    ],
    "ExposeHeaders": [
      "ETag"
    ],
    "MaxAgeSeconds": 3600
  }
]
```

**Reemplaza `https://struky-admin.vercel.app` con la URL real de tu admin en Vercel.**

## ⚠️ SI NO CONFIGURAS CORS:

Verás errores como:
- "Failed to fetch"
- "CORS policy blocked"
- "Access-Control-Allow-Origin"

## ✅ Después de configurar CORS:

1. Espera 1-2 minutos (propagación)
2. Recarga tu admin
3. Intenta subir una imagen
4. **Debería funcionar** ✨

---

**Esto es el último paso para que funcione completamente.**
