# 🚀 Guía de Inicio Rápido - Vintage Music App

## ✅ **Estado Actual**

- ✅ PostgreSQL corriendo en Docker (puerto 5432)
- ✅ Redis corriendo en Docker (puerto 6379)
- ✅ Backend NestJS iniciado en modo desarrollo
- ✅ App móvil lista para ejecutar

## 📱 **Iniciar la Aplicación Móvil**

### **Opción 1: Emulador Android**

1. **Abrir el emulador de Android Studio**
   ```bash
   # Verifica que el emulador esté corriendo
   flutter emulators
   flutter emulators --launch <nombre_emulador>
   ```

2. **Ejecutar la aplicación**
   ```bash
   cd apps/frontend
   flutter run
   ```

### **Opción 2: Dispositivo Físico Android**

1. **Habilitar modo desarrollador en tu dispositivo**
   - Ve a Configuración > Acerca del teléfono
   - Toca 7 veces en "Número de compilación"
   - Activa "Depuración USB" en Opciones de desarrollador

2. **Conectar el dispositivo por USB**
   ```bash
   # Verificar dispositivos conectados
   flutter devices
   ```

3. **Ejecutar la aplicación**
   ```bash
   cd apps/frontend
   flutter run
   ```

### **Opción 3: Chrome (Web - Para pruebas rápidas)**

1. **Ejecutar en navegador**
   ```bash
   cd apps/frontend
   flutter run -d chrome
   ```

## 🔧 **Configuración Importante**

### **URL del Backend**

La aplicación móvil necesita conectarse al backend. Hay dos escenarios:

#### **1. Emulador Android**
El emulador usa `10.0.2.2` para conectarse al localhost de tu PC:

```dart
// apps/frontend/lib/core/config/app_config.dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000/api',  // Para emulador
);
```

#### **2. Dispositivo Físico**
Necesitas usar la IP local de tu PC:

1. **Obtener tu IP local:**
   ```powershell
   ipconfig
   # Busca "Dirección IPv4" de tu adaptador de red (ej: 192.168.1.100)
   ```

2. **Actualizar la configuración:**
   ```dart
   // apps/frontend/lib/core/config/app_config.dart
   static const String baseUrl = String.fromEnvironment(
     'API_BASE_URL',
     defaultValue: 'http://TU_IP_LOCAL:3000/api',  // ej: http://192.168.1.100:3000/api
   );
   ```

## 🧪 **Probar el Registro**

### **1. Registro de Usuario Normal**

1. Abrir la app
2. Tocar "Regístrate"
3. Llenar el formulario:
   - Nombre: Juan
   - Apellido: Pérez
   - Email: juan@example.com
   - Username: juanperez
   - Contraseña: 123456
   - Seleccionar: **Usuario**
4. Aceptar términos y condiciones
5. Tocar "Crear Cuenta"

### **2. Registro de Artista**

1. Abrir la app
2. Tocar "Regístrate"
3. Llenar el formulario:
   - Nombre: María
   - Apellido: García
   - Email: maria@example.com
   - Username: mariamusic
   - Contraseña: 123456
   - Seleccionar: **Artista**
   - Nombre artístico: María Music
4. Aceptar términos y condiciones
5. Tocar "Crear Cuenta"

### **3. Login**

1. Usar las credenciales del registro:
   - Email: juan@example.com
   - Contraseña: 123456
2. Tocar "Iniciar Sesión"

## 🗄️ **Verificar la Base de Datos**

### **Conectar a PostgreSQL**

```bash
# Opción 1: Usando Docker
docker exec -it music-app-postgres psql -U vintage_user -d vintage_music

# Opción 2: Usando psql local
psql -h localhost -U vintage_user -d vintage_music
```

### **Consultas Útiles**

```sql
-- Ver usuarios registrados
SELECT id, email, username, first_name, last_name, role, is_active 
FROM "user" 
ORDER BY created_at DESC;

-- Ver artistas
SELECT a.id, a.stage_name, u.email, u.username
FROM artist a
JOIN "user" u ON a.user_id = u.id
ORDER BY a.created_at DESC;

-- Contar usuarios por rol
SELECT role, COUNT(*) as total
FROM "user"
GROUP BY role;
```

## 🐛 **Solución de Problemas**

### **Error: No se puede conectar al backend**

1. **Verificar que el backend esté corriendo:**
   ```bash
   curl http://localhost:3000/api/health
   # O visitar: http://localhost:3000/api
   ```

2. **Verificar PostgreSQL:**
   ```bash
   docker ps | grep postgres
   ```

3. **Ver logs del backend:**
   ```bash
   # Los logs deberían mostrar:
   # [Nest] Application is running on: http://localhost:3000
   ```

### **Error: Database connection failed**

1. **Reiniciar PostgreSQL:**
   ```bash
   docker restart music-app-postgres
   ```

2. **Verificar credenciales en el backend:**
   ```bash
   # apps/backend/src/database/data-source.ts
   # URL: postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music
   ```

### **Error: Cannot find module**

```bash
cd apps/frontend
flutter clean
flutter pub get
flutter run
```

## 📊 **Endpoints del Backend**

### **Autenticación**
- `POST /api/auth/register` - Registrar usuario
- `POST /api/auth/login` - Iniciar sesión
- `GET /api/auth/profile` - Obtener perfil
- `POST /api/auth/change-password` - Cambiar contraseña

### **Usuarios**
- `GET /api/users` - Listar usuarios
- `GET /api/users/:id` - Obtener usuario por ID
- `PATCH /api/users/:id` - Actualizar usuario

### **Artistas**
- `GET /api/artists` - Listar artistas
- `GET /api/artists/:id` - Obtener artista por ID
- `PATCH /api/artists/:id` - Actualizar artista

## 🎯 **Pruebas Recomendadas**

1. ✅ **Registro de usuario normal**
2. ✅ **Login con usuario registrado**
3. ✅ **Ver perfil en la pantalla de inicio**
4. ✅ **Cerrar sesión y volver a login**
5. ✅ **Registro de artista**
6. ✅ **Login como artista**
7. ✅ **Verificar persistencia de sesión** (cerrar y abrir la app)

## 📱 **Comandos Útiles Flutter**

```bash
# Ver dispositivos disponibles
flutter devices

# Ejecutar en un dispositivo específico
flutter run -d <device_id>

# Hot reload (durante ejecución)
r

# Hot restart (durante ejecución)
R

# Quit
q

# Ver logs
flutter logs

# Limpiar build
flutter clean

# Verificar configuración
flutter doctor
```

## 🔍 **Debug en Chrome DevTools**

Si ejecutas en un dispositivo/emulador:

```bash
# Mientras la app está corriendo, visita:
http://localhost:9100

# O usa:
flutter run --observatory-port=9100
```

## ✅ **Checklist de Verificación**

- [ ] PostgreSQL corriendo en Docker
- [ ] Backend iniciado sin errores
- [ ] App móvil compilada correctamente
- [ ] URL del backend configurada correctamente
- [ ] Dispositivo/emulador conectado
- [ ] Registro de usuario exitoso
- [ ] Login exitoso
- [ ] Datos persistentes en la base de datos

¡Listo! Tu aplicación de autenticación está completamente funcional. 🎉
