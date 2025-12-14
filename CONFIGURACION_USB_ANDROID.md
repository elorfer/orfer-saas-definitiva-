# Configuración para Dispositivo Android por USB

## Solución Rápida con ADB Reverse

Si tienes tu dispositivo Android conectado por **cable USB**, la forma más fácil es usar `adb reverse` para crear un túnel del puerto.

### Pasos:

1. **Asegúrate de tener ADB instalado y tu dispositivo reconocido:**
   ```bash
   adb devices
   ```
   Deberías ver tu dispositivo listado. Si no aparece, verifica que:
   - El cable USB esté bien conectado
   - La depuración USB esté habilitada en tu dispositivo
   - Hayas aceptado la autorización de depuración USB en el dispositivo

2. **Crea el túnel del puerto:**
   ```bash
   adb reverse tcp:3001 tcp:3001
   ```
   Esto redirige el puerto 3001 del dispositivo al puerto 3001 de tu computadora.

3. **Verifica que el backend esté corriendo:**
   ```bash
   cd apps/backend
   npm run start:dev
   ```
   El backend debe estar corriendo en el puerto 3001.

4. **Ejecuta la app:**
   ```bash
   cd apps/frontend
   flutter run
   ```
   
   La app ahora usará `http://localhost:3001` que se redirige automáticamente a tu computadora.

### Verificar que funciona:

Desde tu dispositivo Android, abre un navegador y visita:
```
http://localhost:3001/api/v1/health
```

Si ves una respuesta JSON, el túnel está funcionando correctamente.

## Si prefieres usar WiFi en lugar de USB

Si quieres usar la conexión WiFi en lugar del túnel USB:

1. **Encuentra la IP local de tu computadora:**
   - **Windows:** `ipconfig` (busca "IPv4 Address")
   - **Linux/Mac:** `ifconfig` o `ip addr`

2. **Ejecuta la app con la opción WiFi:**
   ```bash
   flutter run --dart-define=USE_WIFI=true
   ```

3. **Asegúrate de actualizar la IP en el código:**
   - Abre: `apps/frontend/lib/core/config/app_config.dart`
   - Busca: `_developmentUrlAndroidWiFi`
   - Cambia `192.168.1.100` por tu IP local

## Solución de Problemas

### Error: "adb: command not found"
- Instala Android SDK Platform Tools
- O usa Flutter que incluye ADB en su instalación
- En Windows, asegúrate de que ADB esté en tu PATH

### Error: "device unauthorized"
- Acepta la autorización de depuración USB en tu dispositivo Android
- Verifica que la depuración USB esté habilitada en las opciones de desarrollador

### El túnel se desconecta
- Si desconectas el cable USB, el túnel se pierde
- Vuelve a ejecutar: `adb reverse tcp:3001 tcp:3001`
- O crea un script para automatizarlo

### El backend no responde
- Verifica que el backend esté corriendo: `npm run start:dev` en `apps/backend`
- Verifica que esté en el puerto 3001
- Prueba acceder desde tu navegador en la computadora: `http://localhost:3001/api/v1/health`

## Automatización (Opcional)

Puedes crear un script para automatizar el proceso:

**Windows (setup-usb.bat):**
```batch
@echo off
echo Configurando túnel ADB...
adb reverse tcp:3001 tcp:3001
echo Túnel configurado. Ahora puedes ejecutar: flutter run
pause
```

**Linux/Mac (setup-usb.sh):**
```bash
#!/bin/bash
echo "Configurando túnel ADB..."
adb reverse tcp:3001 tcp:3001
echo "Túnel configurado. Ahora puedes ejecutar: flutter run"
```

## Ventajas de usar USB con ADB Reverse

✅ No necesitas estar en la misma red WiFi  
✅ Más rápido y estable que WiFi  
✅ No necesitas configurar IPs  
✅ Funciona automáticamente con localhost  
✅ Más seguro (no expone el puerto en la red)

















