# 🚀 CAMBIOS FINALES PARA PRESIGNED URLs

## ✅ YA HECHO (Backend):
1. ✅ Endpoint `/upload/presigned-url` funcionando
2. ✅ Método antiguo `uploadFile` deshabilitado
3. ✅ Hook React `usePresignedUpload` creado
4. ✅ API Client actualizado para aceptar URLs

## 📝 PENDIENTE (Frontend - TÚ debes hacer):

### 1. Modificar `apps/admin/src/app/dashboard/artists/create/page.tsx`:

Agregar después de la línea 50:

```typescript
const { uploadFile: uploadToR2 } = usePresignedUpload({
  apiUrl: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001',
  authToken: typeof window !== 'undefined' ? localStorage.getItem('token') || '' : '',
  folder: 'images',
  onProgress: (progress) => console.log('Upload:', progress),
});
```

### 2. En el método `handleSubmit` (línea 115):

Agregar ANTES de `apiClient.createArtist`:

```typescript
// Subir imágenes con presigned URLs
let profileUrl: string | undefined;
let coverUrl: string | undefined;

if (profile) {
  toast.loading('Subiendo foto de perfil...');
  const { publicUrl } = await uploadToR2(profile);
  profileUrl = publicUrl;
  toast.dismiss();
  toast.success('Foto subida');
}

if (cover) {
  toast.loading('Subiendo portada...');
  const { publicUrl } = await uploadToR2(cover);
  coverUrl = publicUrl;
  toast.dismiss();
  toast.success('Portada subida');
}
```

### 3. Cambiar las líneas 146-147:

**ANTES:**
```typescript
profileFile: profile,
coverFile: cover,
```

**AHORA:**
```typescript
profileUrl, 
coverUrl,
```

---

## 🎯 RESULTADO ESPERADO:

1. Usuario sube imagen en el admin
2. Hook `usePresignedUpload` pide presigned URL al backend
3. Imagen se sube DIRECTO a R2 (sin pasar por Railway)
4. Se recibe `publicUrl`
5. Se envía esa URL a `createArtist`
6. ✅ **SIN ERRORES SSL**

---

## 🔧 ALTERNATIVA RÁPIDA:

Si no quieres modificar create/page.tsx ahora, puedes:
1. Desplegar el backend
2. Usar el endpoint directo en Postman/Thunder Client para probar presigned URLs

**Endpoint:**
```
POST https://tu-backend.railway.app/api/v1/upload/presigned-url
Headers: Authorization: Bearer {tu_token}
Body:
{
  "fileName": "test.png",
  "contentType": "image/png",
  "folder": "images"
}
```

Recibirás:
```json
{
  "uploadUrl": "https://...",
  "key": "images/...",
  "publicUrl": "https://...",
  "expiresIn": 300
}
```

Luego haz PUT a `uploadUrl` con el archivo.

---

**Estado**: Backend listo. Frontend requiere 3 cambios menores.
