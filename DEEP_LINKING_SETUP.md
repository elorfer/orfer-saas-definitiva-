# 🔗 DEEP LINKING - Password Reset

## ✅ **IMPLEMENTACIÓN COMPLETADA**

Sistema de deep linking para abrir la app directamente cuando el usuario hace click en el link del email.

---

##🎯 **Cómo Funciona:**

### **1. Usuario pide reset password**
```
Usuario → Forgot Password → Backend genera token → Email enviado
```

### **2. Email con deep link**
```
De: Struky <noreply@struky.com>
Link: struky://reset-password/abc123xyz456...
```

### **3. Usuario hace click**
```
Android detecta: struky://
→ Abre la app automáticamente
→ Navega a /reset-password/abc123xyz456
→ Pantalla ResetPasswordScreen se muestra
```

### **4. Usuario cambia contraseña**
```
Ingresa nueva contraseña → Backend actualiza → ✅ Éxito
```

---

## 📱 **Configuración Android:**

### **AndroidManifest.xml:**
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    
    <!-- Deep link personalizado -->
    <data android:scheme="struky" android:host="reset-password" />
    
    <!-- HTTPS para producción -->
    <data android:scheme="https" android:host="struky.com" android:pathPrefix="/reset-password" />
</intent-filter>
```

---

## 🔗 **Formatos de Link:**

### **Desarrollo:**
```
struky://reset-password/TOKEN_AQUI
```

### **Producción:**
```
https://struky.com/reset-password/TOKEN_AQUI
```

---

## 🧪 **Testing:**

### **Probar deep link en Android:**

```bash
# Con ADB
adb shell am start -W -a android.intent.action.VIEW -d "struky://reset-password/test123"

# Debería abrir la app en la pantalla de reset
```

### **Probar flujo completo:**

1. Registra un usuario en la app
2. Pide "Forgot Password"
3. Revisa el email en `strukyapp@gmail.com`
4. Click en el botón "Restablecer Contraseña"
5. La app debería abrirse automáticamente
6. Pantalla de reset password visible
7. Cambia la contraseña
8. ✅ Éxito

---

## 🚀 **Para iOS (Pendiente):**

Agregar en `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.struky.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>struky</string>
        </array>
    </dict>
</array>
```

---

## ⚙️ **Variables de Entorno:**

### **Desarrollo (.env):**
```env
NODE_ENV=development
RESEND_API_KEY=re_iNvNbLSy_2jbh9SZYVuBVPHLRxaKmZNPi
```

### **Producción (Railway):**
```env
NODE_ENV=production
RESEND_API_KEY=re_iNvNbLSy_2jbh9SZYVuBVPHLRxaKmZNPi
```

---

## 📋 **Checklist:**

- [x] AndroidManifest.xml configurado
- [x] Backend genera deep link correcto
- [x] GoRouter ya maneja /reset-password/:token
- [x] ResetPasswordScreen ya existe
- [ ] Probar en dispositivo real
- [ ] Configurar iOS (opcional)

---

## 🎉 **Status:**

```
✅ Deep linking configurado para Android
✅ Email con link correcto
✅ Backend actualizado
✅ Ruta en GoRouter correcta
✅ Pantalla de reset funcional
🚀 Listo para testing
```

---

**Próximo paso:** Rebuild de la app y prueba con un email real.
