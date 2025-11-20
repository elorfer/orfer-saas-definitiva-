# 🔄 Cambio de Puerto: 3000 → 3001

## ⚠️ Problema Resuelto

**Problema:** Docker Desktop estaba usando el puerto 3000, causando conflictos.

**Solución:** El servidor NestJS ahora corre en el puerto **3001**.

---

## 📋 URLs Actualizadas

### Backend
- **Health Check:** `http://localhost:3001/api/v1/health`
- **Swagger Docs:** `http://localhost:3001/api/v1/docs`
- **API Base:** `http://localhost:3001/api/v1`

### Endpoints Importantes
- **Upload:** `POST http://localhost:3001/api/v1/songs/upload`
- **Status:** `GET http://localhost:3001/api/v1/songs/upload/:uploadId/status`

---

## 🔧 Cambios Realizados

1. **`main.ts`** - Puerto por defecto cambiado a 3001
2. **CORS** - URLs actualizadas para incluir puerto 3001
3. **Android Emulator** - URL actualizada a `10.0.2.2:3001`

---

## ⚙️ Configuración

Si necesitas cambiar el puerto, puedes:

1. **Usar variable de entorno:**
   ```env
   PORT=3001
   ```

2. **O modificar `main.ts`:**
   ```typescript
   const port = configService.get('PORT', 3001);
   ```

---

## 📝 Actualizar Configuraciones

### Admin Panel
Actualiza `NEXT_PUBLIC_API_URL` en `.env`:
```env
NEXT_PUBLIC_API_URL=http://localhost:3001
```

### App Móvil (Flutter)
Actualiza `app_config.dart`:
```dart
static const String baseUrl = 'http://localhost:3001';
// O para Android emulator:
static const String baseUrl = 'http://10.0.2.2:3001';
```

---

## ✅ Estado

- ✅ Servidor configurado para puerto 3001
- ✅ CORS actualizado
- ✅ URLs documentadas
- ⚠️ **Necesitas actualizar Admin Panel y App Móvil**

---

**Nota:** El puerto 3000 sigue siendo usado por Docker Desktop. No intentes cambiarlo de vuelta sin resolver el conflicto primero.







