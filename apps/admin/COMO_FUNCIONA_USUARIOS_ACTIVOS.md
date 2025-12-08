# 🔍 Cómo Funciona: Usuarios Activos en Tiempo Real

## 📌 Respuesta Directa

**SÍ, deberías aparecer como usuario activo, PERO solo si reproduces música desde tu app Flutter.**

---

## 🎯 ¿Qué Cuenta Como "Usuario Activo"?

El sistema actual cuenta usuarios que:
- ✅ **Reprodujeron música en los últimos 5 minutos**
- ❌ NO cuenta solo por estar "conectado"
- ❌ NO cuenta solo por tener la app abierta

---

## ⚙️ Cómo Funciona el Sistema

### 1. **Cuando Reproduces Música en Flutter**

```
Flutter App → Reproduce canción → Backend registra en play_history
```

El backend debe registrar la reproducción en la tabla `play_history` cuando:
- Obtienes la URL de streaming de una canción
- O cuando se completa una reproducción

### 2. **El Sistema de Usuarios Activos Consulta**

El backend busca en `play_history`:
```sql
SELECT COUNT(DISTINCT user_id) 
FROM play_history 
WHERE played_at >= (NOW() - 5 minutos)
```

### 3. **Se Actualiza en Tiempo Real**

- El WebSocket emite el conteo actualizado
- El admin panel se actualiza instantáneamente

---

## ✅ Para Que Aparezcas Como Activo

Necesitas cumplir estos pasos:

### 1. **Estar Autenticado**
- Debes estar logueado en la app Flutter
- Tener un token JWT válido

### 2. **Reproducir Música**
- Reproduce una canción desde la app
- La reproducción debe registrarse en el backend

### 3. **Verificar que se Registre**
- El backend debe guardar un registro en `play_history`
- Esto debe suceder cuando obtienes la URL de streaming

---

## 🔍 Verificación

### Para Verificar si Funciona:

1. **Reproduce una canción** en tu app Flutter
2. **Espera unos segundos** (máximo 10 segundos)
3. **Revisa el admin panel** - deberías aparecer como usuario activo

### Si NO Apareces:

1. **Verifica que reprodujiste música** (no solo abriste la app)
2. **Verifica que la reproducción se registró**:
   - Revisa los logs del backend
   - Busca llamadas a `/streaming/song/:id/stream`
   - Verifica que se llame a `recordPlay()`

3. **Verifica la base de datos**:
   ```sql
   SELECT * FROM play_history 
   ORDER BY played_at DESC 
   LIMIT 10;
   ```

---

## 🔧 Cómo se Registra una Reproducción

### Backend (Ya Implementado)

El método `getStreamUrl()` en `streaming.service.ts` llama a `recordPlay()`:

```typescript
async getStreamUrl(songId: string, userId: string) {
  // ... código para obtener URL
  await this.recordPlay(songId, userId); // ✅ Registra la reproducción
  return { streamUrl, hlsUrl };
}
```

### Flutter (Debe Estar Implementado)

La app Flutter debe llamar al endpoint:
```
GET /streaming/song/:id/stream
```

Esto automáticamente:
- ✅ Obtiene la URL de streaming
- ✅ Registra la reproducción en `play_history`
- ✅ Te marca como usuario activo

---

## 📊 Ventana de Tiempo

- **Usuarios Activos**: Últimos **5 minutos**
- **Actualización**: En tiempo real (cuando cambia)
- **Si no reproduces por 5 minutos**: Dejas de aparecer como activo

---

## 🚨 Problemas Comunes

### 1. "Reproduje música pero no aparezco"

**Solución:**
- Verifica que la reproducción se registró en el backend
- Revisa los logs del backend cuando reproduces
- Espera unos segundos (puede haber un pequeño delay)

### 2. "Aparezco pero desaparece rápido"

**Normal**: Si no sigues reproduciendo música, desapareces después de 5 minutos.

### 3. "No sé si se está registrando"

**Verificación:**
```sql
-- En tu base de datos PostgreSQL
SELECT 
  ph.played_at,
  u.email,
  s.title
FROM play_history ph
JOIN users u ON ph.user_id = u.id
JOIN songs s ON ph.song_id = s.id
ORDER BY ph.played_at DESC
LIMIT 10;
```

---

## ✅ Resumen

**Para aparecer como usuario activo desde tu app Flutter:**

1. ✅ Debes estar autenticado
2. ✅ Debes **reproducir música** (no solo abrir la app)
3. ✅ La reproducción debe registrarse en `play_history`
4. ✅ Aparecerás como activo por los próximos 5 minutos

**Si solo abres la app pero no reproduces música, NO aparecerás como activo.**

---

## 🔄 Próximas Mejoras (Opcional)

Si quisieras contar usuarios "conectados" (no solo reproduciendo), necesitarías:

1. **WebSocket en Flutter** para notificar conexión
2. **Sistema de heartbeat** para mantener la conexión viva
3. **Tracking de sesiones** en lugar de solo reproducciones

Pero el sistema actual (basado en reproducciones) es más útil porque muestra usuarios realmente activos usando la plataforma.

---

**¿Tienes dudas? Reproduce una canción y verifica en el admin panel.**





