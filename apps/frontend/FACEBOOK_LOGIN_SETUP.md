# 🔴 Configuración de Facebook Login

## ⚠️ ACCIÓN REQUERIDA

Para que el login con Facebook funcione, debes completar la configuración siguiendo estos pasos:

---

## 📋 Paso 1: Crear y Configurar App en Facebook Developers

1. **Ir a Facebook Developers**
   - Abre: https://developers.facebook.com/
   - Inicia sesión con tu cuenta de Facebook

2. **Crear Nueva Aplicación**
   - Click en "Crear aplicación"
   - Tipo: **Consumer** (para login de usuarios)
   - Nombre de la app: **Struky**
   - Click en "Crear aplicación"

3. **Obtener Credenciales**
   - Ve a **Configuración** → **Básica**
   - Anota estos valores:
     - **ID de la aplicación** (App ID)
     - **Clave secreta de la aplicación** (App Secret)

4. **Agregar Plataforma Android**
   - En **Configuración** → **Básica**, scroll hacia abajo
   - Click en **+ Agregar plataforma** → **Android**
   - Nombre del paquete de Google Play: `com.struky.app`
   
5. **Obtener Key Hash (SHA1)**
   - Abre terminal en tu proyecto
   - Ejecuta:
     ```powershell
     cd android
     .\gradlew signingReport
     ```
   - Busca el SHA1 en la sección `debug`
   - Conviértelo a formato Facebook ejecutando:
     ```powershell
     keytool -exportcert -alias androiddebugkey -keystore ~\.android\debug.keystore | openssl base64
     ```
   - Password: `android` (cuando te lo pida)
   - Copia el hash generado y pégalo en **Hash de claves** en Facebook

6. **Habilitar Inicio de Sesión con Facebook**
   - En el panel lateral, ve a **Productos**
   - Busca **Inicio de sesión con Facebook** → Click en **Configurar**
   - En **Configuración de Inicio de sesión con Facebook**, ve a **Configuración**

---

## 📋 Paso 2: Configurar Firebase

1. **Ir a Firebase Console**
   - Abre: https://console.firebase.google.com/
   - Selecciona tu proyecto: **struky-5bdb8**

2. **Habilitar Autenticación con Facebook**
   - Ve a **Authentication** → **Sign-in method**
   - Busca **Facebook** y haz click
   - Activa el botón de **Habilitar**
   
3. **Configurar Credenciales**
   - **ID de la aplicación**: Pega el App ID de Facebook del Paso 1
   - **Clave secreta de la aplicación**: Pega el App Secret de Facebook
   - Click en **Guardar**
   
4. **Copiar URI de Redireccionamiento**
   - Firebase te mostrará un **URI de redireccionamiento de OAuth**
   - Cópialo (algo como: `https://struky-5bdb8.firebaseapp.com/__/auth/handler`)

5. **Volver a Facebook Developers**
   - Ve a **Productos** → **Inicio de sesión con Facebook** → **Configuración**
   - En **URI de redireccionamiento de OAuth válidos**, pega el URI de Firebase
   - Click en **Guardar cambios**

---

## 📋 Paso 3: Actualizar Configuración en Android

**IMPORTANTE:** Debes reemplazar los placeholders en el archivo `strings.xml`

1. **Abrir el archivo:**
   ```
   android/app/src/main/res/values/strings.xml
   ```

2. **Reemplazar los valores:**
   ```xml
   <!-- ANTES -->
   <string name="facebook_app_id">XXXXXXXXXX</string>
   <string name="fb_login_protocol_scheme">fbXXXXXXXXXX</string>
   <string name="facebook_client_token">YYYYYYYYYY</string>

   <!-- DESPUÉS (con tus valores reales) -->
   <string name="facebook_app_id">1234567890123456</string>
   <string name="fb_login_protocol_scheme">fb1234567890123456</string>
   <string name="facebook_client_token">tu_client_token_aqui</string>
   ```

   **Dónde obtener cada valor:**
   - **facebook_app_id**: Es el "ID de la aplicación" de Facebook (paso 1.3)
   - **fb_login_protocol_scheme**: Es `fb` + tu App ID (ej: si tu App ID es 123456, será `fb123456`)
   - **facebook_client_token**: En Facebook Developers → **Configuración** → **Avanzada** → busca "Token de cliente"

---

## 📋 Paso 4: Rebuild y Probar

1. **Limpiar y reconstruir:**
   ```powershell
   flutter clean
   flutter run
   ```

2. **Probar el login:**
   - Abre la app
   - Ve a la pantalla de registro/login
   - Click en el botón "Facebook"
   - Debería abrir el navegador o la app de Facebook
   - Autoriza la aplicación
   - ¡Deberías quedar logueado! 🎉

---

## 🐛 Troubleshooting

### Error: "App Not Setup"
- Verifica que hayas habilitado "Inicio de sesión con Facebook" en Facebook Developers
- Verifica que el package name sea `com.struky.app`

### Error: "Invalid Key Hash"
- Verifica que hayas agregado el key hash correcto en Facebook Developers
- Genera el hash nuevamente y asegúrate de copiarlo completo

### Error: "Given URL is not allowed"
- Verifica que hayas agregado el URI de redireccionamiento de Firebase en Facebook Developers

### No abre Facebook
- Verifica que `strings.xml` tenga los valores correctos (no placeholders)
- Haz `flutter clean` y vuelve a compilar

---

## ✅ Checklist de Configuración

- [ ] App creada en Facebook Developers
- [ ] App ID y App Secret obtenidos
- [ ] Plataforma Android agregada con package name `com.struky.app`
- [ ] Key hash (SHA1) agregado en Facebook
- [ ] Inicio de sesión con Facebook habilitado en Facebook Developers
- [ ] Firebase Authentication configurado con Facebook
- [ ] URI de redireccionamiento agregado en Facebook Developers
- [ ] `strings.xml` actualizado con valores reales (no placeholders)
- [ ] `flutter clean` y rebuild ejecutados
- [ ] Login con Facebook probado y funcionando

---

## 📚 Referencias

- [Facebook Login para Android - Documentación oficial](https://developers.facebook.com/docs/android/getting-started)
- [flutter_facebook_auth Package](https://pub.dev/packages/flutter_facebook_auth)
- [Firebase Authentication con Facebook](https://firebase.google.com/docs/auth/android/facebook-login)
