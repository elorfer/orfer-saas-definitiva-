# 📋 Estrategia de Gestión de Suscripciones

## 🎯 Problema Actual

Tienes **DOS sistemas de suscripciones** que NO están sincronizados:

1. **RevenueCat** (compras in-app)
2. **Base de datos local** (activaciones manuales)

Cuando el admin quita premium manualmente:
- ✅ La DB se actualiza a `inactive`  
- ❌ RevenueCat sigue diciendo `isPremium: true`
- 🐛 **Conflicto:** La app no sabe cuál creer

---

## ✅ Solución: Fuente de Verdad Jerárquica

### **Regla de Oro:**

```
SI usuario tiene suscripción activa en RevenueCat (compra in-app)
  → RevenueCat es la fuente de verdad
  → Ignorar cambios manuales del admin (no puedes quitar una compra de Google/Apple)
  
SI usuario NO tiene suscripción RevenueCat
  → Base de datos local es la fuente de verdad
  → El admin puede activar/desactivar libremente
```

---

## 🔧 Implementación Recomendada

### **Backend:**

1. **Agregar campo `subscriptionSource` a la tabla `users`:**
   ```sql
   ALTER TABLE users ADD COLUMN subscription_source VARCHAR(20) DEFAULT 'manual';
   -- Valores posibles: 'revenuecat', 'manual'
   ```

2. **Modificar `markAsPremium` (activación manual):**
   ```typescript
   // Solo permitir si NO tiene suscripción RevenueCat activa
   if (user.revenuecatCustomerId) {
     throw new BadRequestException(
       'Este usuario tiene suscripción activa vía RevenueCat. ' +
       'No se puede modificar manualmente.'
     );
   }
   
   user.subscriptionStatus = 'active';
   user.subscriptionSource = 'manual';
   ```

3. **Modificar `removePremium`:**
   ```typescript
   // Solo permitir si es manual
   if (user.subscriptionSource === 'revenuecat') {
     throw new BadRequestException(
       'No se puede quitar una suscripción de RevenueCat. ' +
       'Debe cancelarse desde Google Play/App Store.'
     );
   }
   
   user.subscriptionStatus = 'inactive';
   ```

### **Frontend (App Flutter):**

1. **Modificar `_syncPremiumStatusToBackend`:**
   ```dart
   // NO sobrees cribi r el backend si tiene suscripción RevenueCat
   // Solo sincronizar en una dirección: RevenueCat → Backend
   
   Future<void> _syncPremiumStatusToBackend() async {
     if (_currentUserId == null) return;
     
     final customerInfo = await Purchases.getCustomerInfo();
     final hasActiveSubscription = customerInfo.entitlements.active.isNotEmpty;
     
     if (hasActiveSubscription) {
       // Tiene suscripción RevenueCat activa -> activar en backend
       await _makeHttpRequest('POST', '/users/$_currentUserId/premium', body: {
         'expiresAt': premiumExpirationDate?.toIso8601String(),
         'source': 'revenuecat',
       });
     }
     // Si NO tiene suscripción RevenueCat, NO tocar el backend
     // (puede tener activación manual)
   }
   ```

2. **Respetar el estado del backend:**
   ```dart
   // Después de sincronizar RevenueCat, SIEMPRE consultar backend
   await _syncPremiumStatusToBackend();
   final user = await AuthService().getProfile(); // Fuente de verdad final
   ```

---

## 🎨 UI en el Admin

**Vista "Usuarios Premium":**

| Usuario | Origen | Expira | Acciones |
|---------|--------|--------|----------|
| juan@example.com | 🛒 RevenueCat | 2026-02-15 | ❌ No editable |
| maria@example.com | 👤 Manual | 2026-01-20 | ✅ Renovar / ❌ Quitar |

**Reglas:**
- Suscripciones **RevenueCat**: Solo lectura, no se pueden quitar
- Suscripciones **Manuales**: Se pueden renovar o quitar

---

## 🚀 Migración

1. Agregar campo `subscription_source` a la BD
2. Marcar usuarios existentes con `revenuecatCustomerId` como `source: 'revenuecat'`
3. Resto como `'manual'`
4. Actualizar lógica del admin
5. Actualizar lógica de sincronización en la app

---

## 📝 Notas

- **RevenueCat** gestiona suscripciones de Google/Apple (NO puedes cancelarlas desde tu backend)
- **Manual** gestiona pagos directos (transferencias, efectivo, etc.)
- Ambos conviven, pero **RevenueCat tiene prioridad** cuando existe
