# Solución: Backend en Docker no accesible desde Emulador Android

## 🔍 Problema

El backend está corriendo en Docker en el puerto 3001 y responde desde `localhost`, pero el emulador Android no puede conectarse usando `10.0.2.2:3001`.

## ✅ Soluciones

### Solución 1: Usar la IP de la Red Local (Recomendado)

En lugar de usar `10.0.2.2`, usa la IP de tu máquina en la red local:

1. **Tu IP actual es:** `192.168.1.6`

2. **Actualizar la configuración en Flutter:**
   
   Edita `apps/frontend/lib/core/config/app_config.dart` y cambia:
   ```dart
   static const String _developmentUrlAndroidEmulator = 'http://192.168.1.6:3001';
   ```

3. **O usar variable de entorno al ejecutar:**
   ```powershell
   flutter run --dart-define=API_BASE_URL=http://192.168.1.6:3001/api/v1
   ```

### Solución 2: Hot Restart Completo de la App

El timeout se cambió a 30 segundos, pero necesitas hacer **hot restart completo**:

1. **En la terminal de Flutter:**
   - Presiona `R` (mayúscula) para hacer **Hot Restart** completo
   - O presiona `r` (minúscula) para hot reload (puede no aplicar cambios de configuración)

2. **O detener y reiniciar la app:**
   ```powershell
   # Detener la app actual (Ctrl+C)
   # Luego reiniciar:
   cd apps/frontend
   flutter run
   ```

### Solución 3: Verificar Firewall de Windows

El firewall puede estar bloqueando las conexiones desde el emulador:

```powershell
# Verificar reglas de firewall para el puerto 3001
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*3001*"}
```

Si no hay reglas, crear una:
```powershell
New-NetFirewallRule -DisplayName "Backend Port 3001" -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow
```

### Solución 4: Verificar que Docker esté escuchando en todas las interfaces

Verificar que el puerto esté mapeado correctamente:
```powershell
docker ps --filter "name=vintage-music-backend" --format "{{.Ports}}"
```

Debería mostrar: `0.0.0.0:3001->3001/tcp`

## 🎯 Prueba Rápida

1. **Desde tu navegador en Windows**, prueba:
   ```
   http://localhost:3001/api/v1/health
   ```
   Debería responder: `{"status":"ok",...}`

2. **Desde el emulador Android**, prueba en el navegador del emulador:
   ```
   http://192.168.1.6:3001/api/v1/health
   ```
   O:
   ```
   http://10.0.2.2:3001/api/v1/health
   ```

## 📝 Estado Actual

- ✅ Backend corriendo en Docker: `0.0.0.0:3001`
- ✅ Backend responde en localhost: `http://localhost:3001/api/v1/health` → 200 OK
- ✅ Puerto mapeado correctamente: `3001:3001`
- ⚠️ Emulador no puede conectarse vía `10.0.2.2`

## 🔧 Configuración Recomendada

Para desarrollo con Docker + Emulador Android:

```dart
// En app_config.dart
static const String _developmentUrlAndroidEmulator = 'http://192.168.1.6:3001';
```

O usar variable de entorno:
```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.6:3001/api/v1
```









