# 🚀 Guía Completa de Inicio - Vintage Music App

## ✅ **Sistema ya Configurado**

- ✅ PostgreSQL corriendo en Docker (puerto 5432)
- ✅ Redis corriendo en Docker (puerto 6379)
- ✅ Backend con autenticación JWT + bcrypt
- ✅ App móvil con UI profesional

---

## 📋 **Paso a Paso para Iniciar Todo**

### **1️⃣ Iniciar la Base de Datos (PostgreSQL)**

```powershell
# Verificar que PostgreSQL esté corriendo
docker ps | Select-String postgres

# Si no está corriendo, iniciarlo:
docker start music-app-postgres

# Verificar que esté activo:
docker ps
```

### **2️⃣ Iniciar el Backend (NestJS)**

```powershell
# Ir a la carpeta del backend
cd "C:\app definitiva\apps\backend"

# Iniciar en modo desarrollo (con hot-reload)
npm run start:dev
```

**Espera a ver este mensaje:**
```
[Nest] Application is running on: http://[::1]:3000
```

### **3️⃣ Iniciar la Aplicación Móvil**

#### **Opción A: Emulador Android (Recomendado para pruebas)**

```powershell
# Abrir una NUEVA terminal
cd "C:\app definitiva\apps\frontend"

# Ver dispositivos disponibles
flutter devices

# Iniciar el emulador si no está abierto
flutter emulators
flutter emulators --launch <nombre_emulador>

# Ejecutar la app
flutter run
```

#### **Opción B: Dispositivo Físico**

1. **Habilitar modo desarrollador:**
   - Configuración > Acerca del teléfono
   - Tocar 7 veces en "Número de compilación"
   - Activar "Depuración USB"

2. **Conectar por USB y ejecutar:**
   ```powershell
   cd "C:\app definitiva\apps\frontend"
   
   # Verificar dispositivo conectado
   flutter devices
   
   # IMPORTANTE: Obtener tu IP local
   .\get-local-ip.ps1
   
   # Editar app_config.dart con tu IP (ver paso 4)
   
   # Ejecutar
   flutter run
   ```

#### **Opción C: Navegador (Para pruebas rápidas)**

```powershell
cd "C:\app definitiva\apps\frontend"
flutter run -d chrome
```

---

## 🔧 **4️⃣ Configurar URL del Backend**

### **Para Emulador Android** ✅ (Ya configurado)
```dart
// apps/frontend/lib/core/config/app_config.dart
defaultValue: 'http://10.0.2.2:3000/api'
```

### **Para Dispositivo Físico** 📱

1. **Obtener tu IP local:**
   ```powershell
   cd "C:\app definitiva\apps\frontend"
   .\get-local-ip.ps1
   ```

2. **Editar el archivo:**
   ```dart
   // apps/frontend/lib/core/config/app_config.dart
   defaultValue: 'http://TU_IP_LOCAL:3000/api'
   // Ejemplo: 'http://192.168.1.100:3000/api'
   ```

3. **Hot restart la app:**
   - Presiona `R` en la terminal donde corre Flutter

### **Para Web/Chrome** 🌐
```dart
// apps/frontend/lib/core/config/app_config.dart
defaultValue: 'http://localhost:3000/api'
```

---

## 🧪 **5️⃣ Probar el Registro y Login**

### **Registro de Usuario**

1. En la app, toca **"Regístrate"**
2. Llena el formulario:
   ```
   Nombre: Juan
   Apellido: Pérez
   Email: juan@test.com
   Username: juanperez
   Contraseña: 123456
   Tipo: Usuario
   ```
3. Acepta términos y toca **"Crear Cuenta"**
4. Deberías ver la pantalla de inicio con tu perfil

### **Registro de Artista**

1. En la app, toca **"Regístrate"**
2. Llena el formulario:
   ```
   Nombre: María
   Apellido: García
   Email: maria@test.com
   Username: mariamusic
   Contraseña: 123456
   Tipo: Artista
   Nombre artístico: María Music
   ```
3. Crea la cuenta y verás el perfil de artista

### **Login**

1. Cierra sesión (botón en la esquina superior derecha)
2. Usa las credenciales:
   ```
   Email: juan@test.com
   Contraseña: 123456
   ```
3. Toca **"Iniciar Sesión"**

---

## 🗄️ **6️⃣ Verificar en la Base de Datos**

```powershell
# Conectar a PostgreSQL
docker exec -it music-app-postgres psql -U vintage_user -d vintage_music
```

```sql
-- Ver todos los usuarios registrados
SELECT id, email, username, first_name, last_name, role, is_verified, created_at 
FROM "user" 
ORDER BY created_at DESC;

-- Ver artistas
SELECT a.id, a.stage_name, u.email, u.username
FROM artist a
JOIN "user" u ON a.user_id = u.id
ORDER BY a.created_at DESC;

-- Contar usuarios
SELECT role, COUNT(*) as total
FROM "user"
GROUP BY role;

-- Salir
\q
```

---

## 🐛 **Solución de Problemas Comunes**

### ❌ **Error: Cannot connect to database**

```powershell
# Verificar PostgreSQL
docker ps | Select-String postgres

# Si no está corriendo:
docker start music-app-postgres

# Reiniciar backend
cd "C:\app definitiva\apps\backend"
# Ctrl+C para detener
npm run start:dev
```

### ❌ **Error: Cannot connect to backend (desde app móvil)**

1. **Verificar que el backend esté corriendo:**
   ```powershell
   curl http://localhost:3000/api
   ```

2. **Para emulador:** Usar `http://10.0.2.2:3000/api`

3. **Para dispositivo físico:**
   - Obtener IP local: `.\get-local-ip.ps1`
   - Actualizar `app_config.dart`
   - Hot restart: `R` en terminal de Flutter

4. **Verificar firewall:**
   - Windows puede estar bloqueando la conexión
   - Permite Node.js en el firewall

### ❌ **Error: Module not found (Flutter)**

```powershell
cd "C:\app definitiva\apps\frontend"
flutter clean
flutter pub get
flutter run
```

### ❌ **Backend no inicia**

```powershell
cd "C:\app definitiva\apps\backend"
# Reinstalar dependencias
npm install
npm run start:dev
```

---

## 📊 **Endpoints del Backend**

### Autenticación
- `POST /api/auth/register` - Registrar usuario
- `POST /api/auth/login` - Iniciar sesión
- `GET /api/auth/profile` - Obtener perfil (requiere token)
- `POST /api/auth/change-password` - Cambiar contraseña

### Usuarios
- `GET /api/users` - Listar usuarios
- `GET /api/users/:id` - Obtener usuario

### Artistas
- `GET /api/artists` - Listar artistas
- `GET /api/artists/:id` - Obtener artista

---

## 🎯 **Checklist de Verificación**

Antes de reportar un problema, verifica:

- [ ] PostgreSQL corriendo: `docker ps | Select-String postgres`
- [ ] Backend sin errores y mostrando: `Application is running on: http://[::1]:3000`
- [ ] App móvil compilada sin errores
- [ ] URL del backend correcta en `app_config.dart`
- [ ] Dispositivo/emulador conectado: `flutter devices`
- [ ] Internet habilitado en emulador/dispositivo

---

## 📱 **Comandos Útiles Flutter**

```powershell
# Ver dispositivos
flutter devices

# Hot reload (durante ejecución)
r

# Hot restart (durante ejecución)
R

# Quit
q

# Limpiar y reconstruir
flutter clean && flutter pub get && flutter run

# Ver logs detallados
flutter run -v
```

---

## 🎉 **¡Listo!**

Si seguiste todos los pasos:

1. ✅ Backend corriendo en `http://localhost:3000`
2. ✅ App móvil corriendo en tu dispositivo/emulador
3. ✅ Puedes registrarte e iniciar sesión
4. ✅ Los datos se guardan en PostgreSQL

**Próximos pasos:**
- Explorar las funcionalidades de la app
- Agregar más características
- Personalizar el diseño
- Implementar autenticación social (Google, Apple)

---

## 🆘 **¿Necesitas Ayuda?**

Si algo no funciona:

1. Revisa los logs del backend
2. Revisa los logs de Flutter: `flutter logs`
3. Verifica los contenedores Docker: `docker ps`
4. Consulta la sección de solución de problemas arriba

¡Feliz desarrollo! 🚀🎵
