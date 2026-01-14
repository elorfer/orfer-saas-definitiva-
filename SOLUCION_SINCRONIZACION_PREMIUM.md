# 🔧 SOLUCIÓN: SINCRONIZACIÓN MANUAL PREMIUM

## 🎯 **PROBLEMA ACTUAL:**

```
RevenueCat: isPremium = true ✅
Backend: subscription_status = inactive ❌
```

**Causa:** El webhook NO funciona en localhost (RevenueCat no puede acceder a `http://localhost:3000`)

---

## ✅ **SOLUCIÓN IMPLEMENTADA:**

### **1. Código agregado en revenuecat_service.dart**

Ya agregué el método `_syncPremiumStatusToBackend()` que se llama automáticamente cuando cambia el estado premium.

### **2. Falta: Endpoint en el backend**

Necesitas crear un endpoint para que el frontend pueda actualizar el estado premium:

```typescript
// apps/backend/src/modules/auth/auth.controller.ts

@Post('sync-premium')
@UseGuards(AuthGuard('jwt'))
async syncPremiumStatus(@Req() req) {
  const userId = req.user.id;
  
  // Actualizar el usuario a premium
  await this.userRepository.update(userId, {
    subscription_status: 'active',
    premium_plan: 'monthly', // o detectar del request
    premium_expires_at: null, // o calcular fecha
  });
  
  return { success: true, message: 'Premium activated' };
}
```

---

## 🚀 **ALTERNATIVA MÁS SIMPLE (RECOMENDADA):**

### **Usar el AuthProvider que ya tienes:**

El `AuthProvider` ya tiene un método `refreshProfile()` que consulta el backend.

**Modificación sugerida:**

1. **En el backend, agregar lógica** para que cuando se consulta el perfil, también verifique RevenueCat
2. **O mejor aún:** Hacer que el AuthProvider escuche cambios de RevenueCat y actualice automáticamente

---

## 📝 **IMPLEMENTACIÓN RÁPIDA:**

### **Opción 1: Refrescar perfil después de compra**

En `premium_deactivated_screen.dart`, después de comprar:

```dart
// Después de la compra exitosa
await RevenueCatService().purchasePackage(package);

// Sincronizar con backend manualmente
await ref.read(authProvider.notifier).refreshProfile();

// Esperar un momento para que el estado se actualice
await Future.delayed(Duration(seconds: 2));

// Navegar
Navigator.pop(context);
```

### **Opción 2: Endpoint dedicado en backend**

Crear un endpoint que el frontend llama cuando detecta premium:

```typescript
// Backend: auth.controller.ts
@Post('activate-premium')
@UseGuards(AuthGuard('jwt'))
async activatePremium(@Req() req, @Body() body: { appUserId: string }) {
  // Verificar con RevenueCat
  const subscriber = await revenueCatService.getSubscriber(body.appUserId);
  
  if (subscriber.entitlements['Struky Premium']?.isActive) {
    // Actualizar usuario
    await this.userRepository.update(req.user.id, {
      subscription_status: 'active',
    });
  }
  
  return { success: true };
}
```

---

## 🎯 **MI RECOMENDACIÓN:**

### **SOLUCIÓN MÁS SIMPLE (5 minutos):**

**Modificar el método de compra** en `premium_deactivated_screen.dart`:

```dart
Future<void> _handlePurchase(Package package) async {
  try {
    // 1. Comprar
    final success = await RevenueCatService().purchasePackage(package);
    
    if (success) {
      // 2. Refrescar perfil (esto consulta el backend)
      await ref.read(authProvider.notifier).refreshProfile();
      
      // 3. Esperar sincronización
      await Future.delayed(Duration(seconds: 2));
      
      // 4. Verificar si premium se activó
      final user = ref.read(authProvider);
      if (user?.subscriptionStatus == SubscriptionStatus.active) {
        // ✅ TODO BIEN
        Navigator.pop(context);
      } else {
        // ⚠️ Advertir que puede tardar
        showDialog(...);
      }
    }
  } catch (e) {
    _logger.e('Error en compra', error: e);
  }
}
```

---

## 🔍 **VERIFICAR QUE EL BACKEND CONSULTE REVENUECAT:**

En `apps/backend/src/modules/auth/auth.service.ts`, agregar:

```typescript
async getUserProfile(userId: string) {
  const user = await this.userRepository.findOne({ id: userId });
  
  // 🔄 SINCRONIZAR CON REVENUECAT
  try {
    const subscriber = await this.revenueCatService.getSubscriber(userId);
    const isPremium = subscriber.entitlements['Struky Premium']?.isActive || false;
    
    // Actualizar si hay desincronización
    if (isPremium && user.subscription_status !== 'active') {
      await this.userRepository.update(userId, {
        subscription_status: 'active',
      });
      user.subscription_status = 'active';
    }
  } catch (error) {
    this.logger.warn('Error consultando RevenueCat:', error);
  }
  
  return user;
}
```

---

## ✅ **RESUMEN:**

| Opción | Complejidad | Efectividad |
|--------|-------------|-------------|
| Refrescar perfil después de compra | ⭐ Fácil | ⭐⭐ Media |
| Endpoint dedicado | ⭐⭐ Media | ⭐⭐⭐ Alta |
| Backend consulta RevenueCat | ⭐⭐⭐ Difícil | ⭐⭐⭐ Alta |

**Recomendación:** Opción 1 (refrescar perfil) es la más rápida.

---

## 🚀 **¿QUÉ PREFIERES?**

1. **Implementar Opción 1** (yo te doy el código exacto)
2. **Implementar Opción 2** (endpoint dedicado)
3. **Implementar Opción 3** (backend consulta RevenueCat)

Dime cuál quieres y te lo implemento. 🛠️
