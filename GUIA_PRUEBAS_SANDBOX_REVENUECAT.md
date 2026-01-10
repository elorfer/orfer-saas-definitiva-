# 🧪 Guía Completa: Probar Compras en Sandbox de Google Play

Esta guía te enseñará cómo probar suscripciones premium **sin gastar dinero real** usando el entorno Sandbox de Google Play.

---

## 📋 **PRERREQUISITOS**

Antes de empezar, asegúrate de tener:

✅ App subida a **Google Play Console** (aunque sea en Internal Testing)  
✅ Productos/Suscripciones creados en Google Play Console  
✅ RevenueCat configurado y conectado a Google Play  
✅ APK o App Bundle instalado en un dispositivo real o emulador  

⚠️ **IMPORTANTE**: Las compras de prueba **NO funcionan en modo DEBUG** directo desde Android Studio. Debes usar un APK firmado subido a Play Console.

---

## 🎯 **PARTE 1: Configurar Productos en Google Play Console**

### Paso 1: Crear una suscripción de prueba

1. Ve a **Google Play Console**
2. Selecciona tu app **"Struky"**
3. En el menú lateral, ve a **"Monetization"** → **"Subscriptions"**
4. Haz clic en **"Create subscription"**
5. Completa los datos:

```
Subscription ID: premium_monthly
Name: Struky Premium Mensual
Description: Acceso premium a todas las funciones de Struky sin anuncios
```

6. En **"Base plans"**, crea un plan mensual:
   - **Billing period**: 1 month
   - **Price**: $4.99 USD (o el precio que prefieras)
   
7. Haz clic en **"Save"**

### Paso 2: Activar la suscripción

1. Una vez creada, haz clic en **"Activate"**
2. RevenueCat detectará automáticamente este producto

---

## 🎯 **PARTE 2: Configurar Testers de Licencia**

Google Play tiene dos tipos de cuentas de prueba:

### Opción A: License Testers (RECOMENDADO)

Los **License Testers** pueden hacer compras sin ser cobrados.

1. En Google Play Console, ve a **"Setup"** → **"License testing"**
2. En **"License testers"**, agrega emails de cuentas de Google:
   ```
   tu-email-de-prueba@gmail.com
   ```
3. En **"License test response"**, selecciona:
   - ✅ **LICENSED** (esto permite compras de prueba sin cargos)

4. Haz clic en **"Save changes"**

⚠️ **IMPORTANTE**: 
- Usa cuentas de Google **diferentes** a la que administra la Play Console
- Las cuentas deben estar ya agregadas al dispositivo de prueba

### Opción B: Internal Testers

1. Ve a **"Testing"** → **"Internal testing"**
2. Crea un **"Internal testing track"**
3. Sube tu APK/AAB
4. En **"Testers"**, agrega una lista de emails:
   ```
   tu-email-de-prueba@gmail.com
   otro-email@gmail.com
   ```
5. Guarda los cambios

Los testers recibirán un link para descargar la app desde Play Store.

---

## 🎯 **PARTE 3: Preparar la App para Testing**

### Paso 3: Generar APK de Release

⚠️ **NO uses "flutter run"** - Debes generar un APK firmado.

1. Abre tu terminal en el directorio del proyecto:
   ```powershell
   cd c:\appdefinitiva\apps\frontend
   ```

2. Genera el APK de release:
   ```powershell
   flutter build apk --release
   ```

3. El APK estará en:
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```

### Paso 4: Subir APK a Internal Testing

1. Ve a **Google Play Console** → **Internal testing**
2. Haz clic en **"Create new release"**
3. Sube el APK generado
4. Completa la descripción:
   ```
   Versión de prueba para testing de compras premium
   ```
5. Haz clic en **"Save"** y luego **"Review release"**
6. Finalmente **"Start rollout to Internal testing"**

⏱️ La app estará disponible para testers en **1-2 horas**.

---

## 🎯 **PARTE 4: Instalar la App en el Dispositivo de Prueba**

### Paso 5: Descargar desde Play Store (RECOMENDADO)

1. En tu dispositivo de prueba, inicia sesión con la cuenta de tester
2. Abre el email de invitación de Google Play
3. Haz clic en el link de descarga
4. Acepta ser tester
5. Descarga e instala la app desde Play Store

### Opción Alternativa: Instalación manual (si no puedes esperar)

Si necesitas probar inmediatamente:

1. Copia el APK al dispositivo:
   ```powershell
   adb push build/app/outputs/flutter-apk/app-release.apk /sdcard/
   ```

2. Instala el APK:
   ```powershell
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

⚠️ **NOTA**: Con instalación manual, las compras pueden no funcionar correctamente.

---

## 🎯 **PARTE 5: Probar Compras en Sandbox**

### Paso 6: Realizar una compra de prueba

1. **Abre la app Struky** en tu dispositivo de prueba
2. **Inicia sesión** con tu cuenta
3. **Ve a la pantalla de Premium/Suscripciones**
4. **Selecciona el plan** "Premium Mensual"
5. **Toca "Suscribirte"**

### Paso 7: Flujo de compra de prueba

Aparecerá el diálogo de Google Play con:

```
🎯 Suscripción de prueba
───────────────────────
Struky Premium Mensual
$4.99/mes

⚠️ This is a test purchase
You will not be charged

[Subscribe]  [Cancel]
```

Si ves **"This is a test purchase"**, significa que estás en modo Sandbox ✅

6. **Toca "Subscribe"**
7. **Confirma** (puede pedir autenticación biométrica o contraseña)

### Paso 8: Verificar que funcionó

1. **En la app**: El estado premium debe activarse inmediatamente
2. **Logs de Flutter**: Deberías ver:
   ```
   ✅ RevenueCat inicializado correctamente
   🎯 isPremium: true
   📅 Expires: 2026-02-09T...
   ```

3. **En RevenueCat Dashboard**:
   - Ve a **"Customers"**
   - Busca tu usuario
   - Deberías ver la suscripción activa

4. **En tu Backend**:
   - El webhook debería haber llegado
   - Verifica en los logs:
     ```
     📥 Webhook recibido: INITIAL_PURCHASE
     ✅ Premium activado para usuario: [tu-user-id]
     ```

---

## 🎯 **PARTE 6: Probar Diferentes Escenarios**

### Escenario 1: Restaurar Compras

1. **Desinstala la app**
2. **Reinstálala**
3. **Inicia sesión** con la misma cuenta
4. **Ve a Suscripciones**
5. **Toca "Restaurar compras"**

✅ **Resultado esperado**: El estado premium se restaura sin pedir pago.

### Escenario 2: Cancelar Suscripción

1. **Abre Google Play Store**
2. Ve a **"Account"** → **"Payments & subscriptions"** → **"Subscriptions"**
3. Localiza **"Struky Premium Mensual"**
4. Toca **"Cancel subscription"**
5. Confirma la cancelación

✅ **Resultado esperado**:
- En RevenueCat: El webhook `CANCELLATION` llega a tu backend
- En la app: El usuario sigue siendo premium hasta la fecha de expiración
- En tu DB: `isPremium` sigue en `true` pero no se renovará

### Escenario 3: Expiración de Suscripción

En **Sandbox**, las suscripciones se **aceleran**:

| Duración Real | Duración en Sandbox |
|---------------|---------------------|
| 1 semana      | 5 minutos          |
| 1 mes         | 5 minutos          |
| 3 meses       | 10 minutos         |
| 6 meses       | 15 minutos         |
| 1 año         | 30 minutos         |

Para probar expiración:

1. **Realiza una compra**
2. **Espera 5-6 minutos**
3. **Verifica que el premium se desactive automáticamente**

✅ **Resultado esperado**:
- Webhook `EXPIRATION` llega a tu backend
- `isPremium` cambia a `false`
- La app muestra el estado free nuevamente

### Escenario 4: Cambio de Plan

1. **Compra Premium Mensual**
2. **Cambia a Premium Anual** (si lo tienes configurado)

✅ **Resultado esperado**:
- Webhook `PRODUCT_CHANGE` llega
- `premiumExpiresAt` se actualiza
- La app refleja el nuevo plan

---

## 🎯 **PARTE 7: Debugging de Problemas**

### Problema 1: "Item not available for purchase"

**Causa**: El producto no está activo o la app no está publicada en Internal Testing

**Solución**:
1. Verifica que el producto esté **"Active"** en Play Console
2. Asegúrate de que la app esté en **Internal Testing** track
3. Espera 1-2 horas después de activar el producto

### Problema 2: "This version of the app is not configured for billing"

**Causa**: La app no está firmada correctamente o no viene de Play Store

**Solución**:
1. Usa el APK descargado **desde Play Store**
2. NO uses el APK generado localmente
3. Verifica que tu `applicationId` en `build.gradle` coincida con el de Play Console

### Problema 3: El webhook no llega al backend

**Causa**: URL del webhook incorrecta o servidor no accesible

**Solución**:
1. En RevenueCat Dashboard, verifica la URL del webhook
2. Debe ser **pública** y accesible desde internet (usa ngrok en desarrollo)
3. Verifica logs en tu backend
4. Prueba el endpoint manualmente:
   ```bash
   curl -X POST https://tu-backend.com/api/webhooks/revenuecat
   ```

### Problema 4: "You will be charged" en vez de "This is a test purchase"

**Causa**: No estás usando una cuenta de tester

**Solución**:
1. Verifica que tu cuenta esté en la lista de **License Testers**
2. Espera 15 minutos después de agregarla
3. Cierra sesión y vuelve a iniciar en el dispositivo

### Problema 5: isPremium no se actualiza en la app

**Causa**: El servicio RevenueCat no hace sync automático

**Solución**:
1. Llama manualmente a `RevenueCatService().checkPremiumStatus()`
2. Escucha el stream `premiumStatusStream`
3. Verifica que `initialize()` se haya llamado correctamente

---

## 🎯 **PARTE 8: Verificar Todo el Flujo End-to-End**

### Checklist completo:

- [ ] 1. Producto creado y activo en Play Console
- [ ] 2. RevenueCat configurado con Service Account
- [ ] 3. Cuenta de tester agregada en Play Console
- [ ] 4. APK subido a Internal Testing
- [ ] 5. App descargada desde Play Store en dispositivo de prueba
- [ ] 6. Compra realizada con mensaje "This is a test purchase"
- [ ] 7. Estado premium activado en la app
- [ ] 8. Webhook recibido en el backend
- [ ] 9. Campo `isPremium` actualizado en PostgreSQL
- [ ] 10. Restauración de compras funciona correctamente

---

## 🚀 **SIGUIENTE PASO: Producción**

Una vez que todo funcione en Sandbox:

### Para pasar a producción:

1. **Publica la app** en Production track
2. **Remueve** las cuentas de License Testers (opcional)
3. Los usuarios reales **SÍ serán cobrados**
4. Las suscripciones tendrán **duración real** (no acelerada)
5. Google Play cobrará su comisión del **15%** (primeros $1M) o **30%**

---

## 📊 **Logs Útiles para Debugging**

### En Flutter:

```dart
// Habilita logs de RevenueCat
Purchases.setLogLevel(LogLevel.debug);

// Verifica estado después de compra
final isPremium = await RevenueCatService().checkPremiumStatus();
print('🎯 Is Premium: $isPremium');
```

### En NestJS:

```typescript
// Los logs del webhook mostrarán:
[RevenueCatWebhookController] 📥 Webhook recibido de RevenueCat
[RevenueCatWebhookController] 🎯 Tipo: INITIAL_PURCHASE
[RevenueCatWebhookController] 👤 Usuario: abc-123-def-456
[RevenueCatWebhookController] 📦 Producto: premium_monthly
[RevenueCatService] ✅ Premium activado para usuario@email.com
```

---

## ✅ **¡Listo para Probar!**

Ahora tienes todo lo que necesitas para probar compras premium en Sandbox **sin gastar un centavo**.

**Recuerda:**
- Siempre usa cuentas de tester
- Usa APKs descargados de Play Store
- Las suscripciones se aceleran en Sandbox (5 min = 1 mes)
- Los webhooks son esenciales para sincronizar tu backend

🚀 **¡Happy Testing!**
