# 🚀 Instrucciones de Deploy - Sistema de Verificación de Artistas

## 📋 Checklist Pre-Deploy

### ✅ Backend

1. **Ejecutar Migración SQL**
   ```sql
   -- Ejecutar el archivo:
   apps/backend/migrations/add_is_verified_to_artists.sql
   
   -- O manualmente en PostgreSQL:
   ALTER TABLE artists ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE NOT NULL;
   UPDATE artists SET is_verified = TRUE WHERE verification_status = TRUE;
   CREATE INDEX IF NOT EXISTS idx_artists_is_verified ON artists(is_verified) WHERE is_verified = TRUE;
   ```

2. **Verificar Endpoints**
   - ✅ `PATCH /artists/:id/verify` - Funcional
   - ✅ `PATCH /artists/:id/unverify` - Funcional
   - ✅ `GET /artists/verified` - Funcional

3. **Reiniciar Backend**
   ```bash
   cd apps/backend
   npm run start:dev  # o npm run start:prod
   ```

### ✅ Admin Panel

1. **Verificar Funcionalidad**
   - Ir a: `/dashboard/artists/[id]/edit`
   - Probar botón "Verificar Artista"
   - Probar botón "Quitar verificación"
   - Verificar que los cambios se reflejen

2. **No requiere build** (Next.js en modo dev)

### ✅ Flutter

1. **Regenerar Modelos**
   ```bash
   cd apps/frontend
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

2. **Verificar Integraciones**
   - Badge aparece en tarjetas de artistas
   - Badge aparece en reproductor de audio
   - Badge aparece en páginas de artista
   - Badge aparece en resultados de búsqueda

3. **Test Manual**
   - Verificar un artista desde admin
   - Verificar que el badge aparece en Flutter
   - Desverificar y verificar que desaparece

---

## 🔍 Verificación Post-Deploy

### Backend
```bash
# Verificar que el campo existe
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'artists' AND column_name = 'is_verified';

# Verificar artistas verificados
SELECT id, stage_name, is_verified, verification_status 
FROM artists 
WHERE is_verified = TRUE;
```

### Admin Panel
- Probar verificar/desverificar artista
- Verificar que el estado se guarda correctamente

### Flutter
- Abrir app y navegar a un artista verificado
- Verificar que el badge azul aparece
- Verificar animaciones y transiciones

---

## 📝 Notas Importantes

1. **Compatibilidad**: El sistema usa tanto `isVerified` como `verificationStatus` para compatibilidad
2. **Cache**: El badge se muestra basándose en `isVerifiedValue` que prioriza `isVerified`
3. **Performance**: El badge está optimizado para no afectar FPS en listas grandes
4. **Seguridad**: Solo admins pueden verificar/desverificar artistas

---

**Estado**: ✅ Listo para Deploy













