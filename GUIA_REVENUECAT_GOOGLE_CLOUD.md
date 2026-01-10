# 🔐 Guía Completa: Service Account de Google Cloud para RevenueCat

Esta guía te llevará paso a paso para crear y configurar correctamente la Service Account que conectará Google Play Console con RevenueCat.

---

## 📌 **PARTE 1: Crear el Proyecto en Google Cloud (si no lo tienes)**

### Paso 1: Acceder a Google Cloud Console

1. Ve a: https://console.cloud.google.com/
2. Inicia sesión con la cuenta de Google asociada a tu Google Play Console
3. En la parte superior, haz clic en **"Select a project"**
4. Haz clic en **"NEW PROJECT"**
5. Nombre del proyecto: `Struky Music App`
6. Haz clic en **"CREATE"**

> ⚠️ **IMPORTANTE**: Usa la MISMA cuenta de Google que administra tu app en Google Play Console.

---

## 📌 **PARTE 2: Habilitar Google Play Developer API**

### Paso 2: Activar la API necesaria

1. En Google Cloud Console, ve a **"APIs & Services"** → **"Library"**
2. Busca: `Google Play Android Developer API`
3. Haz clic en el resultado
4. Presiona **"ENABLE"**

⏱️ Esto puede tardar 1-2 minutos en activarse.

---

## 📌 **PARTE 3: Crear la Service Account**

### Paso 3: Crear la cuenta de servicio

1. Ve a **"IAM & Admin"** → **"Service Accounts"**
   - URL directa: https://console.cloud.google.com/iam-admin/serviceaccounts
2. Haz clic en **"+ CREATE SERVICE ACCOUNT"**
3. Completa los datos:
   ```
   Service account name: revenuecat-struky
   Service account ID: revenuecat-struky (se genera automáticamente)
   Description: Service Account para integración de RevenueCat con Google Play
   ```
4. Haz clic en **"CREATE AND CONTINUE"**

### Paso 4: NO asignar roles aquí (lo haremos en Play Console)

1. En la sección **"Grant this service account access to project"**:
   - **DÉJALA EN BLANCO** (no selecciones ningún rol)
2. Haz clic en **"CONTINUE"**
3. En **"Grant users access to this service account"**:
   - También **DÉJALA EN BLANCO**
4. Haz clic en **"DONE"**

---

## 📌 **PARTE 4: Generar las Credenciales JSON**

### Paso 5: Crear la clave privada

1. En la lista de Service Accounts, localiza `revenuecat-struky@...`
2. Haz clic en los **3 puntos verticales** (⋮) a la derecha
3. Selecciona **"Manage keys"**
4. Haz clic en **"ADD KEY"** → **"Create new key"**
5. Selecciona formato **"JSON"**
6. Haz clic en **"CREATE"**

📥 **Se descargará automáticamente un archivo JSON**. Por ejemplo:
```
revenuecat-struky-abc123def456.json
```

> 🔴 **¡MUY IMPORTANTE!** Guarda este archivo en un lugar SEGURO. No lo compartas, no lo subas a Git.

---

## 📌 **PARTE 5: Conectar Service Account con Google Play Console**

### Paso 6: Copiar el email de la Service Account

1. Abre el archivo JSON que descargaste
2. Busca el campo `"client_email"`, se verá así:
   ```json
   "client_email": "revenuecat-struky@struky-music-app-123456.iam.gserviceaccount.com"
   ```
3. **Copia ese email completo**

### Paso 7: Dar permisos en Google Play Console

1. Ve a: https://play.google.com/console/
2. Selecciona tu app **"Struky"**
3. En el menú lateral, ve a **"Users and permissions"** (Usuarios y permisos)
4. Haz clic en **"Invite new users"** (Invitar nuevos usuarios)
5. Pega el email de la Service Account:
   ```
   revenuecat-struky@struky-music-app-123456.iam.gserviceaccount.com
   ```

### Paso 8: Asignar SOLO los permisos necesarios

En la sección **"App permissions"** (Permisos de la aplicación):

1. Busca y selecciona tu app **"Struky"**
2. Haz clic en **"Apply"**
3. En **"Account permissions"**, **marca ÚNICAMENTE**:

   ✅ **View app information and download bulk reports** (Solo lectura de métricas básicas)
   
   ✅ **View financial data, orders, and cancellation survey responses**
   
   ✅ **Manage orders and subscriptions** (CRÍTICO para RevenueCat)

4. **NO marques:**
   - ❌ Release apps to production
   - ❌ Manage store presence
   - ❌ Manage testing
   - ❌ Otros permisos de administración

5. Haz clic en **"Send invitation"**

> ⚠️ La service account aparecerá inmediatamente en la lista pero puede tardar **hasta 48 horas** en tener permisos activos. Normalmente funciona en 30 minutos.

---

## 📌 **PARTE 6: Configurar RevenueCat**

### Paso 9: Subir las credenciales a RevenueCat

1. Ve a tu dashboard de RevenueCat: https://app.revenuecat.com/
2. Selecciona tu proyecto **"Struky"** (o créalo si no existe)
3. Ve a **"Project Settings"** → **"Google Play"**
4. En la sección **"Service Credentials"**:
   - Haz clic en **"Upload credentials file"**
   - Selecciona el archivo JSON descargado (`revenuecat-struky-abc123def456.json`)
5. RevenueCat mostrará un mensaje de éxito ✅

### Paso 10: Configurar tu app

1. Copia tu **"Google App-specific Shared Secret"** desde:
   - Google Play Console → Tu app → Monetization setup → Licensing
2. Pégalo en RevenueCat en **"App-specific Shared Secret"**

### Paso 11: Obtener tu API Key pública de RevenueCat

1. En RevenueCat, ve a **"API keys"**
2. Copia la **"Public API Key"** para Android
3. Guárdala, la necesitarás para configurar el Flutter Service

Ejemplo:
```
goog_AbCdEfGhIjKlMnOpQrStUvWx
```

---

## 📌 **PARTE 7: Verificar la Conexión**

### Paso 12: Test de conexión

1. En RevenueCat, ve a **"Google Play"** settings
2. Deberías ver un mensaje:
   ```
   ✅ Successfully connected to Google Play
   ```

3. Si ves errores:
   - Espera 30-60 minutos (propagación de permisos)
   - Verifica que la API esté habilitada en Google Cloud
   - Confirma que el email de la Service Account coincida

---

## 🎯 **RESUMEN DE PERMISOS EXACTOS**

Para que RevenueCat funcione correctamente, la Service Account necesita:

| Permiso | ¿Por qué? |
|---------|-----------|
| **View financial data, orders, and cancellation survey responses** | Para leer transacciones |
| **Manage orders and subscriptions** | Para validar compras y gestionar suscripciones |

---

## 🔐 **SEGURIDAD: Mejores Prácticas**

✅ **HACER:**
- Guarda el JSON en un gestor de contraseñas (1Password, Bitwarden, etc.)
- Añade `*.json` a tu `.gitignore`
- Usa variables de entorno para API keys
- Revoca credenciales si se filtran

❌ **NUNCA:**
- Subir el JSON a GitHub/GitLab
- Compartir el archivo por email
- Hardcodear API keys en el código

---

## 🚀 **SIGUIENTE PASO**

Una vez completados todos los pasos:

1. ✅ Service Account creada
2. ✅ Credenciales JSON descargadas y guardadas
3. ✅ Permisos configurados en Play Console
4. ✅ Credenciales subidas a RevenueCat
5. ✅ API Key de RevenueCat copiada

**Ahora puedes proceder a implementar el código en Flutter y NestJS** 🎉

---

## 📞 **Troubleshooting**

### Error: "The service account does not have the required permissions"

**Solución:**
1. Verifica que esperaste al menos 30 minutos
2. Confirma que los 2 permisos críticos estén marcados
3. Cierra sesión y vuelve a entrar en Play Console
4. Revoca la invitación y vuelve a invitar

### Error: "Google Play Android Developer API has not been used"

**Solución:**
1. Ve a Google Cloud Console
2. APIs & Services → Library
3. Busca "Google Play Android Developer API"
4. Haz clic en ENABLE
5. Espera 5 minutos

### No veo la opción "Service Credentials" en RevenueCat

**Solución:**
- Asegúrate de estar en la sección de **Android/Google Play**
- No en iOS/App Store
- Actualiza la página

---

✅ **¡Listo! Con esto tendrás la conexión Google Play ↔ RevenueCat completamente funcional.**
