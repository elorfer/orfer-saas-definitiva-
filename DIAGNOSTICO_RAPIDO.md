# Diagnóstico Rápido - Problemas de Conexión

## 🔍 Preguntas para Diagnosticar

1. **¿Qué error específico ves en los logs de Flutter?**
   - ¿Timeout?
   - ¿Connection refused?
   - ¿Otro error?

2. **¿En qué parte de la app falla?**
   - ¿Al registrar usuario?
   - ¿Al verificar username/email?
   - ¿En login?
   - ¿En otra pantalla?

3. **¿Los logs del backend muestran peticiones entrantes?**
   - Ejecuta: `docker logs vintage-music-backend --tail 20`

4. **¿Probaste hacer hot restart completo?**
   - Presiona `R` (mayúscula) en la terminal de Flutter
   - O detén y reinicia: `flutter run`

## ✅ Verificaciones Rápidas

### Backend está corriendo:
```powershell
docker ps --filter "name=vintage-music-backend"
```

### Backend responde:
```powershell
Invoke-WebRequest -Uri "http://localhost:3001/api/v1/health" -UseBasicParsing
```

### Configuración actual:
- URL Emulador: `http://10.0.2.2:3001`
- Timeout: 30 segundos
- Puerto Docker: `3001:3001`

## 🚨 Problemas Comunes

### 1. Emulador sin Internet
- Verifica que el emulador tenga conectividad
- Abre Chrome en el emulador y prueba navegar

### 2. Hot Restart no aplicado
- Haz **hot restart completo** (R mayúscula)
- No uses hot reload (r minúscula)

### 3. Timeout muy corto
- Ya está configurado a 30 segundos
- Verifica que el cambio se aplicó

### 4. Backend no recibe peticiones
- Si no ves logs del backend = emulador no puede alcanzar 10.0.2.2
- Prueba usar IP de red local: `192.168.1.6:3001`











