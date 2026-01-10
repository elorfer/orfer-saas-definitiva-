# 🔐 Configuración de Recuperación de Contraseña con Firebase

## ✅ Sistema Implementado

Tu app ahora usa **Firebase Authentication** para enviar emails profesionales de recuperación de contraseña.

---

## 📋 Variables de Entorno Necesarias

Agrega estas variables a tu `.env` (backend):

```env
# Firebase Admin SDK (para recuperación de contraseña)
FIREBASE_PROJECT_ID=struky-5bdb8
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@struky-5bdb8.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nTuClavePrivada\n-----END PRIVATE KEY-----\n"

# URL del frontend (para el link de recuperación)
FRONTEND_URL=http://localhost:3000
```

---

## 🔑 Cómo Obtener las Credenciales de Firebase

### **Paso 1: Ir a Firebase Console**
1. https://console.firebase.google.com
2. Selecciona tu proyecto: **struky-5bdb8**

### **Paso 2: Generar Service Account Key**
1. Click en ⚙️ **Settings** (Configuración del proyecto)
2. Pestaña **"Service accounts"**
3. Click en **"Generate new private key"**
4. Se descargará un archivo JSON

### **Paso 3: Copiar Credenciales**
Del archivo JSON descargado, copia:

```json
{
  "project_id": "struky-5bdb8",  ← FIREBASE_PROJECT_ID
  "client_email": "firebase-adminsdk-xxx@struky-5bdb8.iam.gserviceaccount.com",  ← FIREBASE_CLIENT_EMAIL
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"  ← FIREBASE_PRIVATE_KEY
}
```

**⚠️ IMPORTANTE:** La private_key debe estar entre comillas y con los `\n` literales.

---

## 🧪 Testing Local

### **Sin Firebase configurado:**
- ✅ Funciona en modo fallback
- ✅ Devuelve token en desarrollo para testing manual
- ✅ No envía email real

### **Con Firebase configurado:**
- ✅ Envía email profesional de Google
- ✅ Link de recuperación automático
- ✅ Logs muestran el link en desarrollo

---

## 🚀 Para Producción (Railway)

### **Agregar variables en Railway:**

1. Railway Dashboard → Tu proyecto
2. **Variables** tab
3. Agregar:
   ```
   FIREBASE_PROJECT_ID=struky-5bdb8
   FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@struky-5bdb8.iam.gserviceaccount.com
   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
   FRONTEND_URL=https://tuapp.com
   ```

4. **Deploy** automático

---

## 📧 Cómo Funciona

### **Usuario solicita recuperar contraseña:**
```
1. Usuario ingresa email en /forgot-password
2. App llama POST /api/auth/forgot-password
3. Backend verifica que el email existe
4. Firebase genera link único y envía email
5. Usuario recibe email de "noreply@struky-5bdb8.firebaseapp.com"
6. Usuario click en link → redirige a tu app con token
7. Usuario ingresa nueva contraseña
8. POST /api/auth/reset-password con token
9. ✅ Contraseña actualizada
```

### **Email que recibe el usuario:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Struky
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Hola,

Recibimos una solicitud para restablecer 
tu contraseña.

[Restablecer Contraseña]

Este enlace expira en 1 hora.

Si no solicitaste este cambio, ignora 
este correo.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🎨 Personalizar Email (Opcional)

Para personalizar el email de Firebase:

1. Firebase Console → **Authentication**
2. **Templates** (Plantillas)
3. **Password reset** (Restablecer contraseña)
4. Click en ✏️ **Edit template**
5. Personalizar:
   - Nombre del remitente: `Struky`
   - Asunto: `Recupera tu contraseña - Struky`
   - Contenido del email (HTML)

---

## ⚠️ Troubleshooting

### **Error: "Firebase not initialized"**
- ✅ Verifica que las 3 variables estén configuradas
- ✅ Verifica que PRIVATE_KEY tenga los `\n` literales
- ✅ Restart del backend

### **Email no llega:**
- ✅ Revisa spam
- ✅ Verifica que el email existe en Firebase Auth
- ✅ Checa los logs del backend

### **Link expirado:**
- ✅ Los links de Firebase expiran en 1 hora
- ✅ Solicitar nuevo link

---

## 💡 Modo Desarrollo (sin Firebase)

Si no configuras Firebase, el sistema funciona en **modo fallback**:

1. ✅ Genera token único
2. ✅ Guarda en memoria (válido 1 hora)
3. ✅ Devuelve token en respuesta (solo desarrollo)
4. ❌ NO envía email
5. ✅ Puedes copiar el token de los logs y usarlo

**Logs en desarrollo:**
```
[DEV] Token de recuperación para user@email.com: abc123...
```

---

## ✅ Status Actual

- ✅ Endpoint `/api/auth/forgot-password` funcionando
- ✅ Firebase integration lista
- ✅ Fallback mode para desarrollo
- ✅ Frontend con pantalla forgot-password
- ✅ Validaciones de seguridad implementadas

**¡Listo para usar!** 🎉

---

## 🔄 Next Steps (Opcional)

1. Configurar Firebase credentials en `.env`
2. Personalizar template de email en Firebase Console
3. Agregar credenciales a Railway para producción
4. Testing end-to-end del flujo completo
