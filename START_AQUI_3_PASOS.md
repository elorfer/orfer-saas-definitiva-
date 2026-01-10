# ⚡ EMPIEZA AQUÍ: 3 PASOS CRÍTICOS

**Olvida todo lo demás. Solo haz esto AHORA:**

---

## ✅ PASO 1: Ejecutar Migración de BD (1 minuto)

```powershell
cd c:\appdefinitiva\apps\backend
npm run typeorm:run
```

✅ **Listo.** Ya tienes los campos de RevenueCat en tu base de datos.

---

## ✅ PASO 2: Poner tu API Key (2 minutos)

1. Ve a https://app.revenuecat.com/signup (crea cuenta gratis)
2. Crea proyecto "Struky"
3. Ve a **API Keys**
4. Copia tu **Public API Key** de Android (empieza con `goog_`)

5. Pégala aquí:

**Archivo:** `c:\appdefinitiva\apps\frontend\lib\core\services\revenuecat_service.dart`

**Línea 39:** Cambia esto:
```dart
static const String _androidApiKey = '';
```

Por esto:
```dart
static const String _androidApiKey = 'goog_TU_API_KEY_AQUI';
```

✅ **Listo.** Ya puedes usar RevenueCat en desarrollo.

---

## ✅ PASO 3: Inicializar en Login (3 minutos)

**Archivo:** `c:\appdefinitiva\apps\frontend\lib\core\services\auth_service.dart`

Busca donde procesas el login exitoso y agrega:

```dart
import 'package:vintage_music_app/core/services/revenuecat_service.dart';

// Después de login exitoso:
final revenueCat = RevenueCatService();
await revenueCat.initialize(
  userId: userId,  // Tu userId de la DB
  email: email,    // Email del usuario
);
```

✅ **Listo.** RevenueCat ya está funcionando.

---

## 🎉 YA ESTÁ FUNCIONANDO

**Eso es TODO lo que necesitas para desarrollo.**

Reinicia tu app y verás en los logs:
```
✅ RevenueCat inicializado correctamente
🎯 isPremium: false
```

---

## 📌 LO DEMÁS ES PARA DESPUÉS

Todo lo siguiente es **OPCIONAL** y solo lo necesitas cuando vayas a **PRODUCCIÓN:**

- ❌ Service Account de Google (solo para producción)
- ❌ Webhooks (solo para producción)
- ❌ Sandbox testing (solo antes de publicar)
- ❌ Toda esa documentación larga

---

## 🚀 SIGUIENTE PASO (OPCIONAL)

**¿Quieres una pantalla para suscribirse?**

Copia el código del archivo:
`c:\appdefinitiva\apps\frontend\EJEMPLOS_USO_REVENUECAT.dart`

Sección: **EJEMPLO 3** (Paywall)

---

## ✅ RESUMEN

**AHORA:**
1. ✅ Ejecutar migración
2. ✅ Poner API Key
3. ✅ Inicializar en login

**DESPUÉS (cuando publiques):**
- Google Cloud Service Account
- Webhooks
- Testing en Sandbox

---

**¿Ves? Solo 3 pasos. El resto es para después.** 😊

🎯 **Empieza con PASO 1 arriba** ↑
