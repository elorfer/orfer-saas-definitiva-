# Solución: Emulador Android Sin Conectividad de Red

## 🔍 Problema Identificado

El emulador Android NO tiene conectividad de red:
- ❌ No puede cargar Google Fonts (fonts.gstatic.com)
- ❌ No puede conectarse al backend en `192.168.1.6:3001`
- ❌ Timeout en todas las conexiones de red

## ✅ Soluciones

### Solución 1: Habilitar Internet en el Emulador (Recomendado)

1. **Abrir AVD Manager en Android Studio**
2. **Editar el emulador** (ícono de lápiz)
3. **Show Advanced Settings**
4. **En "Network":**
   - Asegúrate que esté configurado para usar NAT o Bridged
   - Si usa NAT, reinicia el emulador

5. **Dentro del emulador:**
   - Abrir **Settings > Network & Internet**
   - Verificar que **Wi-Fi esté activado**
   - Si hay un proxy, desactivarlo temporalmente

### Solución 2: Usar 10.0.2.2 con Backend Fuera de Docker

Si el emulador no puede acceder a la red local, usar `10.0.2.2` que apunta al localhost del HOST:

1. **Detener el backend en Docker:**
   ```powershell
   docker-compose stop backend
   ```

2. **Ejecutar el backend localmente:**
   ```powershell
   cd apps/backend
   npm run start:dev
   ```

3. **Cambiar la configuración en Flutter:**
   ```dart
   static const String _developmentUrlAndroidEmulator = 'http://10.0.2.2:3001';
   ```

### Solución 3: Usar Dispositivo Físico (Más Confiable)

Si tienes un dispositivo físico Android:

1. **Conectar por USB y habilitar depuración USB**
2. **Configurar redirección de puerto:**
   ```powershell
   cd "C:\Users\Usuario\AppData\Local\Android\Sdk\platform-tools"
   .\adb reverse tcp:3001 tcp:3001
   ```

3. **Ejecutar Flutter:**
   ```powershell
   cd apps/frontend
   flutter run --dart-define=USE_PHYSICAL=true
   ```

### Solución 4: Verificar Configuración del Emulador

1. **Cold Boot del Emulador:**
   - Cerrar completamente el emulador
   - En Android Studio: Tools > AVD Manager
   - Click en el dropdown del emulador > **Cold Boot Now**

2. **Verificar DNS del Emulador:**
   - Dentro del emulador: Settings > Network & Internet > Wi-Fi
   - Long press en la red activa > Modify network
   - Advanced options > IP settings: DHCP
   - DNS: 8.8.8.8 y 8.8.4.4 (Google DNS)

## 🎯 Prueba Rápida

**Desde el emulador, abrir navegador web:**
1. Abrir Chrome en el emulador
2. Ir a: `http://192.168.1.6:3001/api/v1/health`
   - Si funciona: El problema es la configuración de Flutter
   - Si no funciona: El problema es la conectividad del emulador

3. Probar también: `http://10.0.2.2:3001/api/v1/health`
   - Si funciona: Usar esta URL en la configuración

## 📝 Estado Actual

- ✅ Backend corriendo en Docker: `localhost:3001` → Responde OK
- ❌ Emulador sin conectividad: No puede alcanzar ninguna IP
- ⚠️ Google Fonts fallando: Confirma falta de Internet

## 🔧 Próximos Pasos

1. **Verificar conectividad del emulador** (usar navegador)
2. **Si funciona el navegador pero no Flutter:** Problema de configuración
3. **Si NO funciona el navegador:** Problema de red del emulador











