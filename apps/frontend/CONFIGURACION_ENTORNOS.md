# 🔧 Configuración de Entornos - Flutter App

## 📋 Resumen

La app ahora detecta **automáticamente** el entorno (desarrollo vs producción) y usa la URL correcta sin configuración manual.

---

## ✅ Cómo Funciona

### Detección Automática

La app usa `kDebugMode` de Flutter para detectar el entorno:

- **Modo DEBUG** (desarrollo): Usa `localhost` o `10.0.2.2` automáticamente
- **Modo RELEASE** (producción): Usa la URL de producción automáticamente

### Prioridad de Configuración

1. **Variable de entorno** `API_BASE_URL` (si está definida)
2. **Modo DEBUG**: URL de desarrollo según la plataforma
3. **Modo RELEASE**: URL de producción

---

## 🎯 URLs por Plataforma

### Desarrollo (Modo DEBUG)

- **Android Emulator**: `http://10.0.2.2:3000/api/v1`
- **iOS Simulator**: `http://localhost:3000/api/v1`
- **Flutter Web**: `http://localhost:3000/api/v1`
- **Desktop**: `http://localhost:3000/api/v1`

### Producción (Modo RELEASE)

- **Todas las plataformas**: `http://backend-alb-1038609925.us-east-1.elb.amazonaws.com/api/v1`

---

## 🚀 Comandos para Ejecutar

### Desarrollo (Modo DEBUG - Automático)

```bash
# Android Emulator (usa localhost automáticamente)
flutter run

# iOS Simulator (usa localhost automáticamente)
flutter run

# Flutter Web (usa localhost automáticamente)
flutter run -d chrome

# Dispositivo físico Android (usa 10.0.2.2 automáticamente)
flutter run -d <device-id>

# Ver dispositivos disponibles
flutter devices
```

**✅ No necesitas configurar nada** - La app detecta automáticamente que está en modo DEBUG y usa localhost.

**Logs esperados:**
```
🔧 MODO DEBUG: Usando URL de desarrollo: http://10.0.2.2:3000
🔗 API Base URL configurada: http://10.0.2.2:3000/api/v1
```

### Producción (Modo RELEASE)

#### Opción 1: Ejecutar en modo RELEASE (para testing)
```bash
# Android
flutter run --release

# iOS
flutter run --release

# Web
flutter run -d chrome --release
```

**⚠️ IMPORTANTE**: Esto usará la URL de producción (AWS).

**Logs esperados:**
```
🚀 MODO RELEASE: Usando URL de producción: http://backend-alb-...
🔗 API Base URL configurada: http://backend-alb-.../api/v1
```

#### Opción 2: Build de producción (APK/AAB)
```bash
# APK
flutter build apk --release

# AAB para Google Play
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

**✅ Automáticamente usa la URL de producción** cuando está en modo RELEASE.

---

## 🔧 Sobrescribir URL (Opcional)

Si necesitas usar una URL específica (por ejemplo, para testing), puedes usar variables de entorno:

### Android/iOS

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:3000
```

### Web

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

---

## 📱 Para Dispositivos Físicos

Si estás usando un **dispositivo físico** y el backend está en tu computadora:

1. **Encuentra tu IP local**:
   ```bash
   # Windows
   ipconfig
   # Busca "IPv4 Address" (ej: 192.168.1.100)
   
   # Mac/Linux
   ifconfig
   # Busca "inet" (ej: 192.168.1.100)
   ```

2. **Ejecuta con la IP específica**:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://192.168.1.100:3000
   ```

---

## ⚠️ Problemas Comunes

### ❌ La app se conecta a producción en desarrollo

**Causa**: Estás ejecutando en modo RELEASE por error.

**Solución**:
```bash
# Asegúrate de ejecutar sin --release
flutter run  # ✅ Correcto
flutter run --release  # ❌ Incorrecto para desarrollo
```

### ❌ No se conecta al backend local

**Verifica**:
1. ✅ El backend está corriendo en `http://localhost:3000`
2. ✅ Estás en modo DEBUG (no RELEASE)
3. ✅ Para Android Emulator, el backend debe estar en `localhost:3000` (la app usa `10.0.2.2` automáticamente)

### ❌ Dispositivo físico no se conecta

**Solución**:
1. Verifica que el backend esté accesible desde tu red local
2. Usa la IP local con `--dart-define`:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://TU_IP_LOCAL:3000
   ```

---

## 🔍 Verificar Qué URL Está Usando

La app imprime en la consola (solo en modo DEBUG) qué URL está usando:

```
🔧 MODO DEBUG: Usando URL de desarrollo: http://10.0.2.2:3000
🔗 API Base URL configurada: http://10.0.2.2:3000/api/v1
```

---

## 📝 Archivo de Configuración

El archivo `apps/frontend/lib/core/config/app_config.dart` contiene toda la lógica.

**No necesitas modificar nada** - La detección es automática.

---

## ✅ Checklist

- [x] ✅ Detección automática de entorno (DEBUG vs RELEASE)
- [x] ✅ URLs correctas por plataforma
- [x] ✅ Soporte para variables de entorno
- [x] ✅ Logs informativos en modo DEBUG
- [x] ✅ Fallback seguro si hay errores

---

**Última actualización**: Noviembre 2025

