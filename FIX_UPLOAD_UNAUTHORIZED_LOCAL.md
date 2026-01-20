# 🔧 FIX: Error "Unauthorized" en Subida de Archivos del Admin (Local)

## 🎯 Problema Identificado

Cuando subes archivos (imágenes/audio) desde el panel de administración en **modo local**, aparecía el error:

```
Error al procesar imagen: Error subiendo archivo: Unauthorized
```

## 🔍 Causa Raíz

1. **Flujo de subida local:**
   - Admin → Backend endpoint `/api/v1/upload/image` o `/upload/audio`
   - Backend → Intenta subir a Cloudflare R2 (cloud storage)
   - **R2 → Retorna "Unauthorized"** porque no hay credenciales válidas en `.env`
   - Backend → Debería hacer fallback a disco local

2. **El problema:**
   - El código intentaba subir a R2 SIEMPRE primero, incluso sin credenciales
   - El error "Unauthorized" se propagaba antes del fallback
   - El admin mostraba error al usuario

## ✅ Solución Implementada

### **Cambio en `apps/backend/src/modules/upload/s3.service.ts`:**

**Antes:**
```typescript
// Intentaba R2 primero, fallaba con "Unauthorized", luego fallback
```

**Ahora:**
```typescript
// 1. Detecta si está en desarrollo SIN credenciales R2
const hasR2Credentials = this.configService.get<string>('R2_ACCOUNT_ID')?.trim() && 
                          this.configService.get<string>('R2_ACCESS_KEY_ID')?.trim() &&
                          this.configService.get<string>('R2_SECRET_ACCESS_KEY')?.trim();

// 2. Si es local SIN R2 → Va DIRECTO a disco local (sin intentar R2)
if (isDevelopment && !hasR2Credentials) {
  console.log('🏠 [Modo Local] Credenciales R2 no configuradas, usando disco local...');
  // Guarda en: uploads/images/{userId}/{uuid}.jpg
  // URL: http://localhost:3001/uploads/images/{userId}/{uuid}.jpg
}

// 3. Si tiene credenciales R2 → Intenta R2, con fallback a disco si falla
```

## 📝 Qué NO se afectó (Producción Segura)

✅ **Producción (Railway con R2):**
- Sigue usando R2 con credenciales válidas
- Presigned URLs siguen funcionando normalmente
- Sin cambios en el comportamiento

✅ **Sistema de archivos estáticos:**
- El backend ya estaba configurado para servir archivos locales (`app.useStaticAssets`)
- Solo se mejoró la lógica de decisión (R2 vs Local)

## 🎬 Cómo Probarlo

1. **Reinicia el backend** (ya hecho):
   ```bash
   npm run dev:backend
   ```

2. **Desde el admin local** (`http://localhost:3002`):
   - Ve a cualquier sección con subida de archivos
   - Sube una imagen o audio
   - **Deberías ver en los logs del backend:**
     ```
     🏠 [Modo Local] Credenciales R2 no configuradas, usando disco local...
     💾 ✅ Guardado en disco local: C:\appdefinitiva\uploads\images\{userId}\{uuid}.jpg
     ```

3. **El archivo se guarda en:**
   ```
   C:\appdefinitiva\uploads\images\{tu-userId}\{archivo}.jpg
   ```

4. **La URL retornada será:**
   ```
   http://localhost:3001/uploads/images/{userId}/{archivo}.jpg
   ```

## 🔄 Flujos por Entorno

### **Local (Sin credenciales R2):**
```
Admin → Backend → 💾 Disco Local → ✅ URL local
```

### **Local (Con credenciales R2):**
```
Admin → Backend → ☁️ R2 → ✅ URL pública
                    ↓ (si falla)
                  💾 Disco Local → ✅ URL local (fallback)
```

### **Producción (Railway con R2):**
```
Admin → Backend → 🔐 Presigned URL → Cliente sube a R2 directamente
```

## 🚨 Notas Importantes

- **NO agregues credenciales R2 a tu `.env` local** si quieres desarrollo 100% local (más rápido, sin dependencias cloud)
- Si ves el mensaje `🏠 [Modo Local] Credenciales R2 no configuradas, usando disco local...` → Todo OK
- Los archivos en `uploads/` son ignorados por Git (están en `.gitignore`)

## ✨ Beneficios

✅ Desarrollo local **más rápido** (sin latencia de R2)  
✅ **Sin errores** por credenciales R2 faltantes  
✅ Producción **sin cambios** (sigue usando R2)  
✅ Fallback automático si R2 falla en dev  
