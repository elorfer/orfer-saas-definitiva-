# Configuración para Dispositivos Android Físicos

## Problema
Si estás probando la app en un dispositivo Android físico y no puedes iniciar sesión, es porque la URL de desarrollo está configurada para el emulador (`10.0.2.2`), que solo funciona dentro del emulador.

## Solución Recomendada: USB con ADB Reverse

**Si tienes el dispositivo conectado por USB**, usa esta solución (más fácil):
👉 Ver: [CONFIGURACION_USB_ANDROID.md](./CONFIGURACION_USB_ANDROID.md)

## Solución Alternativa: WiFi

### Opción 1: Usar variable de entorno (RECOMENDADO)

1. **Encuentra la IP local de tu computadora:**
   - **Windows:** Abre PowerShell o CMD y ejecuta: `ipconfig`
     - Busca "IPv4 Address" en la sección de tu adaptador de red (WiFi o Ethernet)
     - Ejemplo: `192.168.1.100`
   
   - **Linux/Mac:** Abre terminal y ejecuta: `ifconfig` o `ip addr`
     - Busca la IP en `inet` de tu adaptador de red
     - Ejemplo: `192.168.1.100`

2. **Ejecuta la app con la IP correcta:**
   ```bash
   flutter run --dart-define=API_BASE_URL=http://TU_IP:3001/api/v1
   ```
   
   Ejemplo:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://192.168.1.100:3001/api/v1
   ```

### Opción 2: Modificar el código directamente

1. Abre el archivo: `apps/frontend/lib/core/config/app_config.dart`

2. Busca la línea:
   ```dart
   static const String _developmentUrlAndroidPhysical = 'http://192.168.1.100:3001';
   ```

3. Reemplaza `192.168.1.100` con la IP local de tu computadora

4. Recompila la app:
   ```bash
   flutter run
   ```

### Opción 3: Usar variable de entorno DEV_IP

También puedes usar una variable más simple:
```bash
flutter run --dart-define=DEV_IP=192.168.1.100
```

## Verificaciones Adicionales

### 1. Asegúrate de que el backend esté corriendo
```bash
cd apps/backend
npm run start:dev
```

### 2. Verifica que el backend esté escuchando en el puerto correcto
El backend debe estar corriendo en el puerto `3001` y debe estar accesible desde tu red local.

### 3. Verifica la conexión de red
- Tu dispositivo Android y tu computadora deben estar en la **misma red WiFi**
- Asegúrate de que el firewall de tu computadora permita conexiones entrantes en el puerto 3001

### 4. Prueba la conexión manualmente
Desde tu dispositivo Android, abre un navegador y visita:
```
http://TU_IP:3001/api/v1/health
```

Si ves una respuesta JSON, la conexión funciona.

## Solución de Problemas

### Error: "No se pudo conectar al servidor"
1. Verifica que el backend esté corriendo
2. Verifica que la IP sea correcta
3. Verifica que ambos dispositivos estén en la misma red
4. Verifica el firewall de Windows/Mac/Linux

### Error: "Connection timeout"
- El backend puede estar bloqueado por el firewall
- En Windows, permite el puerto 3001 en el firewall
- En Linux/Mac, verifica las reglas de iptables/firewall

### La app funciona en emulador pero no en dispositivo físico
- Esto es normal: el emulador usa `10.0.2.2` que no funciona en dispositivos físicos
- Usa una de las opciones anteriores para configurar la IP correcta

## Notas Importantes

- La IP puede cambiar si te desconectas y reconectas a la red WiFi
- Si cambias de red, actualiza la IP
- Para desarrollo, considera usar un servicio como ngrok para tener una URL fija

