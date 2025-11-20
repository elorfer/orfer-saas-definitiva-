# ⚡ Comandos Rápidos: Generar e Instalar APK

## 🚀 Comandos Esenciales

### APK de Desarrollo (Debug)
```bash
cd apps/frontend

# Generar
flutter build apk --debug

# Instalar
adb install build/app/outputs/flutter-apk/app-debug.apk

# O directamente
flutter install
```

### APK de Producción (Release)
```bash
cd apps/frontend

# Generar (requiere keystore configurado)
flutter build apk --release

# Instalar
adb install build/app/outputs/flutter-apk/app-release.apk
```

### AAB para Google Play
```bash
cd apps/frontend
flutter build appbundle --release
```

---

## 📍 Ubicación de los APKs

- **Debug**: `build/app/outputs/flutter-apk/app-debug.apk`
- **Release**: `build/app/outputs/flutter-apk/app-release.apk`
- **AAB**: `build/app/outputs/bundle/release/app-release.aab`

---

## ✅ Verificación Rápida

### ¿Qué URL usa cada APK?

**Debug APK:**
- Logs mostrarán: `🔧 MODO DEBUG: Usando URL de desarrollo`

**Release APK:**
- Logs mostrarán: `🚀 MODO RELEASE: Usando URL de producción`

---

## 🔧 Utilidades

```bash
# Ver dispositivos
flutter devices

# Ver logs
flutter logs

# Desinstalar
adb uninstall com.vintagemusic.app.vintage_music_app
```

---

**Ver guía completa**: `GUIA_BUILD_APK.md`










