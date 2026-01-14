# 🔍 VERIFICACIÓN WEBHOOK REVENUECAT

## 📋 **CHECKLIST DE VERIFICACIÓN**

### **1. ✅ Código del Webhook**
- ✅ Controlador creado: `revenuecat-webhook.controller.ts`
- ✅ Ruta: `POST /api/webhooks/revenuecat`
- ✅ Servicio: `RevenueCatService.processWebhookEvent()`
- ✅ Seguridad: Validación HMAC SHA-256

---

### **2. 🔍 URL del Webhook**

**Para desarrollo local:**
```
http://localhost:3000/api/webhooks/revenuecat
```

**Para producción (cuando despliegues):**
```
https://tu-dominio.com/api/webhooks/revenuecat
```

---

### **3. ⚙️ CONFIGURACIÓN EN REVENUECAT**

#### **Paso 1: Abrir Dashboard RevenueCat**
1. Ve a: https://app.revenuecat.com
2. Selecciona tu proyecto
3. Ve a: **Project Settings** (⚙️ arriba derecha)
4. Ve a: **Integrations** → **Webhooks**

#### **Paso 2: Configurar Webhook**
1. Click en **+ Add Webhook**
2. **URL:** `http://localhost:3000/api/webhooks/revenuecat` (desarrollo)
3. **Events:** Seleccionar TODOS los eventos
4. **Authorization Header:** (opcional por ahora)

#### **Paso 3: Obtener Webhook Secret (IMPORTANTE)**
1. Después de crear el webhook, RevenueCat te da un **Webhook Secret**
2. Cópialo
3. Agrégalo al `.env`:
   ```bash
   REVENUECAT_WEBHOOK_SECRET=tu_secret_aqui
   ```

---

### **4. 🧪 PROBAR EL WEBHOOK**

#### **Opción A: Test Manual desde RevenueCat**
1. En el dashboard de webhooks
2. Click en tu webhook
3. Click **Send Test**
4. Verifica los logs del backend

#### **Opción B: Compra Real en Sandbox**
1. Compra una suscripción en la app
2. Observa los logs del backend
3. Deberías ver:
   ```
   📥 Webhook recibido de RevenueCat
   📊 EVENTO DE REVENUECAT
   🎯 Tipo: INITIAL_PURCHASE
   👤 Usuario: tu-user-id
   ✅ Webhook procesado exitosamente
   ```

---

### **5. 🗄️ VERIFICAR BASE DE DATOS**

Después de una compra, verifica:

```sql
SELECT 
  id, 
  email, 
  premium_status, 
  premium_plan, 
  premium_expires_at 
FROM users 
WHERE email = 'tu-email@gmail.com';
```

**Debería mostrar:**
- `premium_status = true`
- `premium_plan = 'monthly'` o `'yearly'`
- `premium_expires_at` = fecha futura

---

## 🚨 **PROBLEMA COMÚN: WEBHOOK NO FUNCIONA EN LOCALHOST**

### **¿Por qué?**
RevenueCat necesita una URL pública accesible desde internet.
`http://localhost:3000` NO es accesible desde RevenueCat.

### **Soluciones:**

#### **Opción 1: ngrok (Recomendado para testing)**
```bash
# Instalar ngrok
npm install -g ngrok

# Crear túnel público
ngrok http 3000
```

Esto te dará una URL pública como:
```
https://abc123.ngrok.io
```

Usa esta URL en RevenueCat:
```
https://abc123.ngrok.io/api/webhooks/revenuecat
```

#### **Opción 2: Desplegar a producción**
- Railway, Render, Fly.io, etc.
- Usar la URL de producción en RevenueCat

#### **Opción 3: Actualización manual (temporal)**
Por ahora, puedes:
1. No configurar el webhook
2. Las compras se sincronizan cuando el usuario abre la app
3. `RevenueCatService.syncSubscriptionStatus()` hace la sincronización

---

## 🔍 **VERIFICAR SI EL WEBHOOK ESTÁ CONFIGURADO**

### **En el código del backend:**
```typescript
// En .env
REVENUECAT_WEBHOOK_SECRET=tu_secret_aqui  // ⬅️ ¿Está configurado?
```

### **En RevenueCat Dashboard:**
1. Project Settings → Integrations → Webhooks
2. ¿Hay un webhook configurado? ✅ ❌
3. ¿Cuál es la URL? ___________
4. ¿Está activo? ✅ ❌

---

## ✅ **LO QUE YA FUNCIONA (SIN WEBHOOK)**

Aunque el webhook NO esté configurado, tu app **YA funciona**:

1. ✅ Usuario compra en la app
2. ✅ RevenueCat registra la compra
3. ✅ App sincroniza al abrir (o cada 5 min)
4. ✅ Backend actualiza `premium_status`

**El webhook solo hace esto INSTANTÁNEO** en lugar de esperar sincronización.

---

## 📊 **CÓMO VERIFICAR QUE TODO FUNCIONA**

### **Test Completo:**

1. **Compra una suscripción en la app**
   ```
   Sandbox: Monthly $9.99
   ```

2. **Verifica RevenueCat Dashboard**
   ```
   ✅ ¿Aparece la transacción?
   ✅ ¿Active Customers = 1?
   ```

3. **Verifica la app**
   ```
   ✅ ¿Muestra "Premium activo"?
   ✅ ¿Se quitan los ads?
   ```

4. **Verifica la base de datos**
   ```sql
   SELECT premium_status FROM users WHERE email = 'tu-email';
   ```
   ```
   ✅ ¿premium_status = true?
   ```

5. **Verifica los logs del backend**
   ```
   ✅ ¿Hay logs de sincronización?
   📥 ¿Hay logs de webhook? (si está configurado)
   ```

---

## 🎯 **SIGUIENTE PASO**

Dime:
1. **¿Está configurado el webhook en RevenueCat Dashboard?** (sí/no)
2. **¿Qué URL usaste?** (localhost / ngrok / producción)
3. **¿Ves logs de webhook en el backend?** (sí/no)

Con esa info te diré exactamente qué hacer.

---

## 📝 **RESUMEN RÁPIDO**

| Item | Estado | Acción |
|------|--------|--------|
| Código webhook | ✅ Listo | Ninguna |
| Webhook en Dashboard | ❓ | Verificar |
| WEBHOOK_SECRET en .env | ❓ | Verificar |
| Logs webhook en backend | ❓ | Verificar |
| Base de datos actualizada | ❓ | Verificar |

**Vamos paso por paso.** 🚀
