# 📦 Guía: Generar APK para Desarrollo y Producción

## 📋 Resumen

Esta guía explica cómo generar APKs para desarrollo (debug) y producción (release), y cómo instalarlos en dispositivos.

---

## 🔧 APK de Desarrollo (DEBUG)

### Características:
- ✅ Se conecta automáticamente a `localhost` o `10.0.2.2:3000`
- ✅ Incluye herramientas de debugging
- ✅ Más grande en tamaño
- ✅ Firma automática (no requiere keystore)

### Generar APK de Desarrollo:

```bash
cd apps/frontend

# Generar APK debug
flutter build apk --debug
```

**Ubicación del APK:**
```
apps/frontend/build/app/outputs/flutter-apk/app-debug.apk
```

### Instalar APK de Desarrollo:

#### Opción 1: Instalación directa (ADB)
```bash
# Conectar dispositivo por USB y habilitar depuración USB
flutter install
```

#### Opción 2: Instalación manual
1. Copia el APK al dispositivo
2. Abre el archivo en el dispositivo
3. Permite "Instalar desde fuentes desconocidas" si es necesario
4. Instala la app

#### Opción 3: Desde Android Studio
- Click derecho en el proyecto → Run → Selecciona dispositivo

---

## 🚀 APK de Producción (RELEASE)

### Características:
- ✅ Se conecta automáticamente a la URL de producción (AWS)
- ✅ Optimizado y más pequeño
- ✅ Sin herramientas de debugging
- ✅ Requiere keystore para firmar

### Paso 1: Configurar Keystore (Solo la primera vez)

#### Crear keystore:

```bash
cd apps/frontend/android

# Crear keystore (reemplaza los valores con los tuyos)
keytool -genkey -v -keystore vintage-music-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vintage-music

# Te pedirá:
# - Contraseña del keystore
# - Información personal (nombre, organización, etc.)
```

#### Configurar key.properties:

Crea el archivo `apps/frontend/android/key.properties`:

```properties
storePassword=TU_PASSWORD_DEL_KEYSTORE
keyPassword=TU_PASSWORD_DEL_KEYSTORE
keyAlias=vintage-music
storeFile=../vintage-music-key.jks
```

**⚠️ IMPORTANTE**: Agrega `key.properties` y `*.jks` al `.gitignore`:
```bash
# En apps/frontend/.gitignore
android/key.properties
android/*.jks
android/*.keystore
```

#### Configurar build.gradle.kts:

Edita `apps/frontend/android/app/build.gradle.kts` y agrega al inicio del archivo (después de los imports):

```kotlin
import java.util.Properties
```

Y antes de `android {`:

```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
```

Y dentro de `android {`, antes de `buildTypes {`:

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}
```

Y en `buildTypes { release { } }`:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        // ... resto de configuración
    }
}
```

### Paso 2: Generar APK de Producción

```bash
cd apps/frontend

# Generar APK release (firmado)
flutter build apk --release
```

**Ubicación del APK:**
```
apps/frontend/build/app/outputs/flutter-apk/app-release.apk
```

### Paso 3: Instalar APK de Producción

```bash
# Instalar directamente
flutter install --release

# O manualmente
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 📱 Generar APK Dividido (AAB) para Google Play

Si vas a subir a Google Play Store, usa AAB (Android App Bundle):

```bash
cd apps/frontend

# Generar AAB
flutter build appbundle --release
```

**Ubicación del AAB:**
```
apps/frontend/build/app/outputs/bundle/release/app-release.aab
```

---

## 🔍 Verificar Qué URL Usa Cada APK

### APK Debug:
- Al abrir la app, revisa los logs:
  ```
  🔧 MODO DEBUG: Usando URL de desarrollo: http://10.0.2.2:3000
  ```

### APK Release:
- Al abrir la app, revisa los logs:
  ```
  🚀 MODO RELEASE: Usando URL de producción: http://backend-alb-...
  ```

---

## 📊 Comparación: Debug vs Release

| Característica | Debug APK | Release APK |
|----------------|-----------|-------------|
| **Tamaño** | ~50-80 MB | ~20-40 MB |
| **URL Backend** | `localhost/10.0.2.2` | Producción (AWS) |
| **Debugging** | ✅ Sí | ❌ No |
| **Optimización** | ❌ No | ✅ Sí |
| **Firma** | Automática | Requiere keystore |
| **Hot Reload** | ✅ Sí | ❌ No |
| **Uso** | Desarrollo/Testing | Producción/Usuarios |

---

## 🛠️ Comandos Útiles

### Ver dispositivos conectados:
```bash
flutter devices
```

### Instalar APK específico:
```bash
# Debug
adb install build/app/outputs/flutter-apk/app-debug.apk

# Release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Desinstalar app:
```bash
adb uninstall com.example.vintage_music_app
# O desde el dispositivo: Configuración → Apps → Desinstalar
```

### Ver logs en tiempo real:
```bash
# Debug
flutter logs

# Release (si tienes acceso)
adb logcat | grep flutter
```

---

## ⚠️ Problemas Comunes

### ❌ Error: "key.properties not found"
**Solución**: Crea el archivo `android/key.properties` con la configuración del keystore.

### ❌ Error: "Keystore file not found"
**Solución**: Verifica que el archivo `.jks` esté en `android/` y la ruta en `key.properties` sea correcta.

### ❌ Error: "APK no se instala"
**Solución**:
1. Desinstala la versión anterior primero
2. Verifica que el dispositivo permita "Instalar desde fuentes desconocidas"
3. Verifica que el APK no esté corrupto

### ❌ APK Release se conecta a localhost
**Solución**: Asegúrate de usar `--release`:
```bash
flutter build apk --release  # ✅ Correcto
flutter build apk  # ❌ Genera debug
```

---

## 📝 Resumen de Comandos

### Desarrollo:
```bash
cd apps/frontend
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Producción:
```bash
cd apps/frontend
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Para Google Play:
```bash
cd apps/frontend
flutter build appbundle --release
# Sube app-release.aab a Google Play Console
```

---

## 🔐 Seguridad del Keystore

**⚠️ IMPORTANTE**: 
- **NUNCA** subas el keystore a Git
- **GUARDA** una copia segura del keystore y su contraseña
- **PERDER** el keystore significa no poder actualizar la app en Google Play

**Recomendación**: Guarda el keystore en:
- ✅ Servicio de almacenamiento seguro (Google Drive con encriptación)
- ✅ Gestor de contraseñas (1Password, LastPass)
- ✅ Backup físico seguro

---

**Última actualización**: Noviembre 2025

