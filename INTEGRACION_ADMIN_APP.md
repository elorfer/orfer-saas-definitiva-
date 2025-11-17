# 🔗 Guía de Integración: Admin Web + App Móvil

Esta guía explica cómo están conectados el **Panel de Administración Web** y la **Aplicación Móvil Flutter** a través del **Backend NestJS**.

---

## 🏗️ **Arquitectura del Sistema**

```
┌─────────────────┐         ┌─────────────────┐
│  Admin Web      │         │  App Móvil      │
│  (Next.js)      │         │  (Flutter)      │
│  :3002          │         │  Android/iOS    │
└────────┬────────┘         └────────┬────────┘
         │                            │
         │  HTTP REST API              │  HTTP REST API
         │  JWT Auth                   │  JWT Auth
         │                            │
         └────────────┬───────────────┘
                      │
                      ▼
              ┌───────────────┐
              │  Backend      │
              │  (NestJS)     │
              │  :3000        │
              │  /api/v1      │
              └───────┬───────┘
                      │
                      ▼
              ┌───────────────┐
              │  PostgreSQL   │
              │  :5432        │
              └───────────────┘
```

---

## 🔧 **Configuración del Backend**

### **CORS Configurado**

El backend (`apps/backend/src/main.ts`) permite peticiones desde:

- ✅ `http://localhost:3002` - Admin Web (puerto principal)
- ✅ `http://localhost:3001` - Admin Web (alternativo)
- ✅ `http://10.0.2.2:3000` - Android Emulator
- ✅ `http://localhost:8080` - Flutter Web

### **Endpoints Compartidos**

Ambas aplicaciones usan los mismos endpoints del backend:

```
Base URL: http://localhost:3000/api/v1
```

**Endpoints principales:**
- `/auth/login` - Autenticación
- `/auth/register` - Registro
- `/auth/profile` - Perfil de usuario
- `/songs` - Gestión de canciones
- `/artists` - Gestión de artistas
- `/playlists` - Gestión de playlists
- `/users` - Gestión de usuarios (solo admin)
- `/analytics` - Estadísticas (solo admin)
- `/payments` - Pagos (solo admin)
- `/streaming/song/:id/stream` - Streaming de audio

---

## 📱 **Configuración de la App Móvil (Flutter)**

### **Archivo de Configuración**

`apps/frontend/lib/core/config/app_config.dart`:

```dart
static String _resolveBaseUrl() {
  final rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000', // Android emulator
  );
  
  // Siempre agrega /api/v1 al final
  return '${rawBaseUrl}/api/v1';
}
```

### **Uso en Servicios**

**AuthService** (`apps/frontend/lib/core/services/auth_service.dart`):
- Se conecta a: `${AppConfig.baseUrl}/auth/login`
- Almacena tokens en: `FlutterSecureStorage`
- Headers: `Authorization: Bearer {token}`

**HomeService** (`apps/frontend/lib/core/services/home_service.dart`):
- Se conecta a: `${AppConfig.baseUrl}/public/artists/top`
- Se conecta a: `${AppConfig.baseUrl}/public/songs/top`
- Incluye tokens automáticamente

---

## 🌐 **Configuración del Admin Web (Next.js)**

### **Archivo de Configuración**

`apps/admin/src/lib/api.ts`:

```typescript
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';

export const api = axios.create({
  baseURL: `${API_BASE_URL}/api/v1`,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});
```

### **Variables de Entorno**

Archivo `.env.local` en `apps/admin/`:

```env
NEXT_PUBLIC_API_URL=http://localhost:3000
NEXTAUTH_URL=http://localhost:3002
NEXTAUTH_SECRET=your-secret-key-here
```

### **Autenticación**

El admin usa **NextAuth** con JWT:
- Credenciales: Email + Password
- Token almacenado en: `localStorage` (access_token)
- Se envía como: `Authorization: Bearer {token}`

---

## 🔐 **Sistema de Autenticación Unificado**

Ambas aplicaciones usan **JWT (JSON Web Tokens)** del mismo backend:

### **Flujo de Autenticación**

1. **Login:**
   ```
   POST /api/v1/auth/login
   Body: { email, password }
   Response: { access_token, user }
   ```

2. **Guardar Token:**
   - **Admin Web:** `localStorage.setItem('access_token', token)`
   - **App Móvil:** `FlutterSecureStorage.write(key: 'auth_token', value: token)`

3. **Usar Token:**
   - Ambas envían: `Authorization: Bearer {token}` en headers

4. **Refresh Token:**
   ```
   POST /api/v1/auth/refresh
   Body: { refresh_token }
   Response: { access_token, refresh_token }
   ```

### **Roles y Permisos**

- **Admin:** Acceso completo al admin web + todas las funcionalidades de la app móvil
- **Artist:** Puede usar la app móvil + panel de artista (si está implementado)
- **User:** Solo puede usar la app móvil

---

## 📊 **Base de Datos Compartida**

Ambas aplicaciones usan la **misma base de datos PostgreSQL**:

```env
DATABASE_URL=postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music
```

### **Tablas Principales**

- `users` - Usuarios del sistema
- `artists` - Perfiles de artistas
- `songs` - Canciones
- `playlists` - Playlists
- `play_history` - Historial de reproducción
- `streaming_stats` - Estadísticas
- `payments` - Pagos

---

## 🚀 **Cómo Iniciar el Sistema Completo**

### **1. Iniciar Backend**

```bash
# Desde la raíz del proyecto
npm run dev:backend-only

# O desde apps/backend
cd apps/backend
npm run start:dev
```

✅ Backend corriendo en: `http://localhost:3000`
✅ Documentación API: `http://localhost:3000/api/docs`

### **2. Iniciar Admin Web**

```bash
# Desde la raíz del proyecto
npm run dev:admin-only

# O desde apps/admin
cd apps/admin
npm run dev
```

✅ Admin corriendo en: `http://localhost:3002`

### **3. Iniciar App Móvil**

```bash
# Desde apps/frontend
cd apps/frontend
flutter run -d emulator-5554
```

✅ App móvil corriendo en dispositivo/emulador Android

### **4. Iniciar Todo Junto**

```bash
# Desde la raíz del proyecto
npm run dev

# O manualmente en terminales separadas:
npm run dev:backend-only   # Terminal 1
npm run dev:admin-only     # Terminal 2
flutter run                # Terminal 3
```

---

## 🔄 **Sincronización de Datos**

### **Tiempo Real**

El admin web y la app móvil **comparten los mismos datos en tiempo real**:

- ✅ Usuarios creados en la app → Aparecen en admin
- ✅ Canciones subidas por artistas → Aparecen en ambas
- ✅ Playlists creadas → Sincronizadas
- ✅ Estadísticas de streaming → Actualizadas en tiempo real

### **Ejemplo de Flujo**

1. **Usuario móvil** crea una playlist → Se guarda en DB
2. **Admin web** puede ver la playlist en `/dashboard/playlists`
3. **Usuario móvil** reproduce una canción → Se registra en `play_history`
4. **Admin web** ve las estadísticas actualizadas en tiempo real

---

## 🎯 **Casos de Uso de Integración**

### **1. Administrador gestiona contenido desde web**

- Admin web crea/edita/elimina canciones
- Los cambios aparecen inmediatamente en la app móvil
- Las canciones están disponibles para los usuarios

### **2. Usuario móvil interactúa con contenido**

- Usuario móvil reproduce canciones
- Las estadísticas se actualizan en el admin web
- El admin puede ver top canciones y artistas

### **3. Artista sube música desde app móvil**

- (Cuando esté implementado) Artista sube canción desde app
- El admin web puede verla y aprobarla
- La canción se hace pública automáticamente

---

## 🛠️ **Troubleshooting**

### **Error: CORS bloqueado**

**Síntoma:** No se pueden hacer peticiones desde admin o app móvil

**Solución:**
1. Verificar que el backend esté corriendo en puerto 3000
2. Verificar CORS en `apps/backend/src/main.ts`
3. Reiniciar el backend después de cambios en CORS

### **Error: Token inválido**

**Síntoma:** 401 Unauthorized en peticiones

**Solución:**
1. Verificar que el token esté almacenado correctamente
2. Verificar que el header `Authorization: Bearer {token}` se envíe
3. Intentar hacer login nuevamente

### **Error: Base de datos no conectada**

**Síntoma:** Errores 500 en peticiones

**Solución:**
1. Verificar que PostgreSQL esté corriendo
2. Verificar `DATABASE_URL` en `.env` del backend
3. Verificar que la base de datos `vintage_music` exista

---

## 📝 **Checklist de Integración**

- [x] Backend configurado con CORS para admin y app móvil
- [x] Admin web conectado al backend en puerto 3000
- [x] App móvil conectada al backend (puerto 10.0.2.2:3000 para Android)
- [x] Autenticación JWT funcionando en ambas apps
- [x] Base de datos compartida y sincronizada
- [x] Endpoints de API documentados y accesibles
- [ ] (Opcional) WebSockets para actualizaciones en tiempo real
- [ ] (Opcional) Notificaciones push sincronizadas

---

## 🎉 **Resultado**

Con esta configuración, tienes:

✅ **Admin Web** gestionando contenido y analíticas  
✅ **App Móvil** para usuarios finales  
✅ **Backend Unificado** sirviendo ambas aplicaciones  
✅ **Base de Datos Compartida** con datos sincronizados  
✅ **Autenticación Unificada** con JWT  

**Todo funcionando juntos como un sistema integrado completo** 🚀

---

*Última actualización: $(date)*

