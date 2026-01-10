# ✅ MEJORA UX - Detectar Usuarios OAuth en Forgot Password

## 🎯 **Mejora Implementada:**

Para evitar confusión de usuarios que se registraron con Google/Facebook:

---

## 📋 **Código a Agregar:**

### **Ubicación:** `apps/backend/src/modules/auth/auth.service.ts`

### **En el método `forgotPassword`, después de línea 419:**

```typescript
// 🔍 Obtener datos del usuario de Firebase Auth para verificar proveedores
let firebaseUser;
try {
  firebaseUser = await admin.auth().getUserByEmail(email);
} catch (firebaseError) {
  // Usuario no existe en Firebase Auth
  if (firebaseError.code === 'auth/user-not-found') {
    this.logger.warn(`⚠️ Usuario existe en DB pero no en Firebase Auth: ${email}`);
    return this.forgotPasswordFallback(email, user.id);
  }
  throw firebaseError;
}

// 🎯 VERIFICAR SI ES USUARIO OAUTH (Google/Facebook)
const providers = firebaseUser.providerData.map(p => p.providerId);
const isPasswordUser = providers.includes('password');
const isGoogleUser = providers.includes('google.com');
const isFacebookUser = providers.includes('facebook.com');

// ⚠️ Usuario solo tiene OAuth (no tiene contraseña)
if (!isPasswordUser && (isGoogleUser || isFacebookUser)) {
  const oauthProvider = isGoogleUser ? 'Google' : 'Facebook';
  this.logger.warn(`⚠️ Usuario ${email} solo tiene login con ${oauthProvider}`);
  
  throw new BadRequestException(
    `Esta cuenta está vinculada a ${oauthProvider}. Por favor, inicia sesión con ese método.`
  );
}
```

### **En el catch block (línea 443), cambiar a:**

```typescript
} catch (error) {
  // Si es BadRequestException (usuario OAuth), re-lanzarla
  if (error instanceof BadRequestException) {
    throw error;
  }

  this.logger.error(`❌ Error al enviar email de recuperación:`, error);
  
  // Fallback a método manual si Firebase falla
  this.logger.warn('⚠️ Usando fallback manual para recuperación de contraseña');
  return this.forgotPasswordFallback(email, user.id);
}
```

---

## 🎯 **Cómo Funciona:**

### **Usuario con Google/Facebook intenta "Forgot Password":**
```
1. Usuario ingresa email en "Olvidé mi contraseña"
2. Backend consulta Firebase Auth
3. Detecta que solo tiene provider "google.com" o "facebook.com"
4. Lanza error: "Esta cuenta está vinculada a Google. Por favor, inicia sesión con ese método."
5. Flutter muestra mensaje amigable ✅
```

### **Usuario con Email/Password:**
```
1. Usuario ingresa email
2. Backend consulta Firebase Auth
3. Detecta que tiene provider "password"
4. Envía email de recuperación ✅
```

---

## 🧪 **Testing:**

### **Caso 1: Usuario OAuth (Google/Facebook)**
```bash
POST /api/v1/auth/forgot-password
{
  "email": "worldoftradersfunded@gmail.com"  # Usuario de Google
}

Response: 400 Bad Request
{
  "message": "Esta cuenta está vinculada a Google. Por favor, inicia sesión con ese método."
}
```

### **Caso 2: Usuario Email/Password**
```bash
POST /api/v1/auth/forgot-password
{
  "email": "test@email.com"  # Usuario normal
}

Response: 201 OK
{
  "message": "Si el email existe, recibirás un enlace para recuperar tu contraseña"
}
```

---

## 📱 **En Flutter:**

El mensaje de error ya se mostrará automáticamente porque el `AuthService` captura el error y lo muestra en un `SnackBar`.

---

## ✅ **Beneficios:**

1. ✅ **Mejor UX:** Usuario sabe inmediatamente por qué no puede resetear
2. ✅ **Menos confusión:** No espera un email que nunca llegará
3. ✅ **Profesional:** Mensaje claro y amigable
4. ✅ **Ahorra tiempo:** Usuario no tiene que contactar soporte

---

## 🔧 **Implementación Manual (5 min):**

1. Abre `apps/backend/src/modules/auth/auth.service.ts`
2. Busca el método `forgotPassword` (línea ~394)
3. Agrega el código después de la línea 419 (después de `if (!admin.apps.length)`)
4. Modifica el catch block como se muestra arriba
5. Reinicia el backend
6. **Prueba** con un usuario de Google/Facebook

---

## 💡 **Nota:**

Esta mejora es **opcional** pero muy recomendada para producción. Por ahora, el sistema funciona con el fallback (devuelve mensaje genérico pero sin email).

**¿Quieres que te ayude a implementarlo manualmente?** Puedo guiarte línea por línea. 🚀
