# ⚡ INICIO RÁPIDO: RevenueCat en Struky (15 minutos)

**Objetivo:** Tener RevenueCat funcionando en modo desarrollo en 15 minutos

---

## 🎯 **ANTES DE EMPEZAR**

Asegúrate de tener:
- ✅ Cuenta en RevenueCat (gratuita): https://app.revenuecat.com/signup
- ✅ App subida a Google Play Console (aunque sea en borrador)
- ✅ Un dispositivo Android o emulador con Google Play Services

---

## 🚀 **PASO 1: Configuración Básica (5 min)**

### 1.1 Crear proyecto en RevenueCat

1. Ve a https://app.revenuecat.com/
2. Crea un nuevo proyecto: **"Struky"**
3. Selecciona plataforma: **Android**
4. Package name: `com.struky.music` (o el tuyo)

### 1.2 Obtener API Key

1. En RevenueCat, ve a **API Keys**
2. Copia la **Public API Key** de Android
   ```
   goog_AbCdEfGhIjKlMnOpQrStUvWx...
   ```

### 1.3 Configurar API Key en Flutter

Edita `apps/frontend/lib/core/services/revenuecat_service.dart`:

```dart
// Línea 39 aproximadamente
static const String _androidApiKey = 'goog_TU_API_KEY_AQUI';
```

---

## 🗄️ **PASO 2: Base de Datos (3 min)**

### 2.1 Ejecutar migración

```powershell
cd c:\appdefinitiva\apps\backend
npm run typeorm:run
```

Deberías ver:
```
✅ Campos de RevenueCat agregados exitosamente a la tabla users
```

### 2.2 Reiniciar backend

```powershell
# Si está corriendo, reinícialo
npm run dev
```

---

## 📱 **PASO 3: Inicializar en la App (4 min)**

### 3.1 Editar auth_service.dart

Abre `apps/frontend/lib/core/services/auth_service.dart`

Encuentra el método donde procesas el login exitoso y agrega:

```dart
import 'package:vintage_music_app/core/services/revenuecat_service.dart';

// Después de un login exitoso:
final userId = response.data['user']['id'];
final email = response.data['user']['email'];

// 🎯 AGREGAR ESTO:
final revenueCat = RevenueCatService();
await revenueCat.initialize(
  userId: userId,
  email: email,
);

// Verificar estado
if (revenueCat.isPremium) {
  print('🎉 Usuario es PREMIUM');
} else {
  print('ℹ️ Usuario es FREE');
}
```

### 3.2 Cerrar sesión de RevenueCat al logout

En tu método de logout:

```dart
Future<void> logout() async {
  // Tu lógica existente...
  
  // Agregar esto:
  await RevenueCatService().logout();
}
```

---

## 🧪 **PASO 4: Probar (3 min)**

### 4.1 Ejecutar la app

```powershell
cd c:\appdefinitiva\apps\frontend
flutter run
```

### 4.2 Hacer login

1. Inicia sesión en tu app
2. Verifica los logs en consola:

```
✅ RevenueCat inicializado correctamente
🎯 isPremium: false
```

Si ves estos logs, **¡funciona!** ✅

---

## ✅ **VERIFICACIÓN FINAL**

Ejecuta el script de verificación:

```powershell
cd c:\appdefinitiva
.\verificar-revenuecat.ps1
```

Deberías ver:
```
TODO PERFECTO! La integracion esta lista.
```

---

## 🎯 **SIGUIENTE PASO: Crear Pantalla de Suscripción**

Copia el código de ejemplo desde:
- `apps/frontend/EJEMPLOS_USO_REVENUECAT.dart`
- Sección: **EJEMPLO 3: Paywall (Pantalla de Suscripción)**

O crea un archivo básico:

```dart
// lib/features/subscription/screens/subscription_screen.dart

import 'package:flutter/material.dart';
import 'package:vintage_music_app/core/services/revenuecat_service.dart';

class SubscriptionScreen extends StatelessWidget {
  final _revenueCat = RevenueCatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hazte Premium')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 100, color: Colors.amber),
            SizedBox(height: 24),
            Text(
              'Struky Premium',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 48),
            ElevatedButton(
              onPressed: () async {
                final packages = await _revenueCat.getAvailablePackages();
                print('Paquetes disponibles: ${packages.length}');
              },
              child: Text('Ver Planes'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Agrega la ruta en tu navegación:

```dart
GoRoute(
  path: '/subscription',
  builder: (context, state) => SubscriptionScreen(),
)
```

---

## 📚 **DOCUMENTACIÓN COMPLETA**

Para configurar todo el flujo de producción:

1. **Service Account de Google:** → `GUIA_REVENUECAT_GOOGLE_CLOUD.md`
2. **Webhooks de Backend:** → `INTEGRACION_REVENUECAT_COMPLETA.md`
3. **Pruebas en Sandbox:** → `GUIA_PRUEBAS_SANDBOX_REVENUECAT.md`
4. **Resumen Ejecutivo:** → `RESUMEN_REVENUECAT.md`

---

## 🚨 **PROBLEMAS COMUNES**

| Error | Solución |
|-------|----------|
| "REVENUECAT_ANDROID_KEY no configurada" | Agrega tu API Key en `revenuecat_service.dart` |
| "RevenueCat no inicializado" | Verifica que `initialize()` se llame después del login |
| Migración falla | Verifica conexión a PostgreSQL |
| "User not found" en logs | Asegúrate de pasar el `userId` correcto |

---

## ✅ **CHECKLIST DE 15 MINUTOS**

- [ ] API Key de RevenueCat copiada y configurada
- [ ] Migración de BD ejecutada
- [ ] Backend reiniciado sin errores
- [ ] `RevenueCatService().initialize()` llamado en login
- [ ] App corre y muestra logs de RevenueCat
- [ ] Script de verificación pasa sin errores

---

## 🎉 **¡LISTO!**

Con esto tienes la base de RevenueCat funcionando. 

**Próximos pasos:**
1. Crear productos en Google Play Console
2. Configurar Service Account (Guía completa en `GUIA_REVENUECAT_GOOGLE_CLOUD.md`)
3. Implementar pantalla de compra
4. Configurar webhooks
5. Probar en Sandbox

**Tiempo total:** 15 minutos ⏱️  
**Dificultad:** Fácil 🟢  
**Estado:** ✅ Funcionando en desarrollo

---

**¿Necesitas ayuda?** Consulta `INTEGRACION_REVENUECAT_COMPLETA.md` para la guía paso a paso completa.
