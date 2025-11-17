# 🚀 GUÍA DE INICIO: Backend y Frontend

Esta guía te muestra cómo iniciar el backend y el frontend paso a paso.

---

## 📋 PREREQUISITOS

Antes de empezar, asegúrate de tener instalado:

- ✅ **Node.js 20+** - Para el backend
- ✅ **Flutter 3.35.0+** - Para la app móvil
- ✅ **PostgreSQL 16+** - Base de datos (o Docker)
- ✅ **Docker & Docker Compose** - Para PostgreSQL y Redis (opcional)

---

## 🗄️ PASO 1: Iniciar la Base de Datos (PostgreSQL y Redis)

### Opción A: Usando Docker (Recomendado) 🐳

```bash
# Desde la raíz del proyecto
docker-compose up -d

# Verificar que los contenedores estén corriendo
docker-compose ps
```

Esto iniciará:
- ✅ PostgreSQL en puerto **5432**
- ✅ Redis en puerto **6379**

### Opción B: PostgreSQL Local

Si tienes PostgreSQL instalado localmente, asegúrate de que esté corriendo en puerto **5432**.

---

## 🔧 PASO 2: Verificar Variables de Entorno

### Backend

Verifica o crea el archivo `.env` en `apps/backend/`:

```env
# Base de datos
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=vintage_user
DB_PASSWORD=vintage_password_2024
DB_DATABASE=vintage_music
# O usa DATABASE_URL completo:
# DATABASE_URL=postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music

# Redis
REDIS_URL=redis://localhost:6379

# JWT
JWT_SECRET=tu_jwt_secret_super_seguro
JWT_EXPIRES_IN=7d

# Puerto del backend
PORT=3000

# Entorno
NODE_ENV=development
```

### Frontend (App Móvil)

El frontend usa configuración por defecto que funciona automáticamente:

- **Android Emulator:** `http://10.0.2.2:3000/api/v1`
- **Dispositivo físico:** Tu IP local + `:3000/api/v1`
- **Flutter Web:** `http://localhost:3000/api/v1`

---

## 🎯 PASO 3: Iniciar el Backend (NestJS)

### Opción A: Desde la raíz del proyecto

```bash
# Desde la raíz del proyecto
npm run dev:backend-only
```

### Opción B: Desde la carpeta del backend

```bash
cd apps/backend
npm install  # Solo la primera vez o si instalaste nuevas dependencias
npm run start:dev
```

### ✅ Verificar que el backend está corriendo

Deberías ver en la consola:

```
🎵 Vintage Music Backend ejecutándose en puerto 3000
📚 Documentación API disponible en http://localhost:3000/api/docs
```

**Backend corriendo en:** `http://localhost:3000`
**Documentación API:** `http://localhost:3000/api/docs`

---

## 📱 PASO 4: Iniciar el Frontend (Flutter)

### Opción A: Desde la raíz del proyecto

```bash
# Desde la raíz del proyecto
npm run dev:frontend-only
```

### Opción B: Desde la carpeta del frontend

```bash
cd apps/frontend

# Instalar dependencias (solo la primera vez)
flutter pub get

# Ejecutar en emulador Android
flutter run -d emulator-5554

# O ejecutar sin especificar dispositivo (elige automáticamente)
flutter run
```

### 📱 Opciones de Ejecución

#### Para Android Emulator:
```bash
cd apps/frontend
flutter run -d emulator-5554
```

#### Para Dispositivo Físico Android:
```bash
cd apps/frontend
flutter run -d <device-id>
# Para ver dispositivos disponibles:
flutter devices
```

#### Para Flutter Web:
```bash
cd apps/frontend
flutter run -d chrome
# O
flutter run -d edge
```

### ✅ Verificar que la app está corriendo

La app debería abrirse automáticamente en tu emulador/dispositivo.

---

## 🧭 Navegación en la app móvil

La app usa **GoRouter + Riverpod** para manejar todas las rutas. El archivo principal está en `apps/frontend/lib/core/navigation/app_router.dart`.

- Rutas disponibles:
  - `/splash`: pantalla de carga mientras se inicializa la sesión.
  - `/login`: formulario de inicio de sesión.
  - `/register`: registro de nuevos usuarios.
  - `/home`: `MainNavigation` con barra inferior y secciones principales.
- Redirecciones automáticas:
  - Usuarios no autenticados siempre son enviados a `/login`.
  - Usuarios autenticados saltan a `/home` y no pueden volver manualmente a `/login` o `/register`.
  - Mientras el estado de autenticación no está inicializado se muestra `/splash`.
- Para navegar dentro de widgets usa:
  - `context.go('/ruta')` para reemplazar la ruta actual.
  - `context.push('/ruta')` si necesitas apilar rutas (por ejemplo, desde login a registro).

> Cualquier cambio futuro en las rutas debe declararse en `goRouterProvider` para mantener la lógica centralizada.

---

## 🚀 INICIAR TODO JUNTO

Si quieres iniciar **backend y frontend juntos** desde la raíz:

```bash
# Desde la raíz del proyecto
npm run dev:backend-admin  # Backend + Admin Web (opcional)
```

O en terminales separadas:

**Terminal 1 - Backend:**
```bash
npm run dev:backend-only
```

**Terminal 2 - Frontend:**
```bash
npm run dev:frontend-only
```

---

## 🎯 VERIFICACIÓN FINAL

### ✅ Backend Funcionando

1. Abre tu navegador en: `http://localhost:3000/api/docs`
2. Deberías ver la documentación de Swagger
3. Prueba el endpoint de health: `http://localhost:3000/api/v1/health`

### ✅ Frontend Funcionando

1. La app debería abrirse en tu emulador/dispositivo
2. Deberías ver la pantalla de login
3. Intenta iniciar sesión o registrarte

---

## 🔍 TROUBLESHOOTING

### ❌ Error: Backend no inicia

**Problema:** Error de conexión a base de datos

**Solución:**
1. Verifica que PostgreSQL esté corriendo: `docker-compose ps`
2. Verifica las variables de entorno en `apps/backend/.env`
3. Reinicia los contenedores: `docker-compose restart`

### ❌ Error: Frontend no se conecta al backend

**Problema:** La app móvil no puede conectarse al backend

**Solución:**

#### ✅ Configuración Automática (Recomendado)

La app **detecta automáticamente** el entorno:
- **Modo DEBUG** (desarrollo): Usa `localhost` o `10.0.2.2` automáticamente
- **Modo RELEASE** (producción): Usa la URL de producción automáticamente

**No necesitas configurar nada manualmente** si ejecutas en modo DEBUG:
```bash
flutter run  # ✅ Automáticamente usa localhost
```

#### Para Android Emulator:
- El backend debe estar en `http://localhost:3000`
- La app usa `http://10.0.2.2:3000` automáticamente (modo DEBUG)

#### Para Dispositivo Físico:
Si necesitas usar una IP específica:
```bash
# Ejecuta con la IP de tu computadora
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:3000
```

#### Para Flutter Web:
- Usa `http://localhost:3000` automáticamente en modo DEBUG
- Verifica que el backend tenga CORS configurado para `localhost:8080`

#### ⚠️ Importante: No ejecutes en modo RELEASE para desarrollo
```bash
flutter run  # ✅ Correcto - Modo DEBUG
flutter run --release  # ❌ Incorrecto - Usará producción
```

### ❌ Error: Puerto 3000 ya en uso

**Problema:** Otro proceso está usando el puerto 3000

**Solución:**
```bash
# Windows - Encontrar proceso
netstat -ano | findstr :3000

# Matar proceso (reemplaza PID con el número que encuentres)
taskkill /PID <PID> /F

# Mac/Linux - Encontrar proceso
lsof -ti:3000

# Matar proceso
kill -9 $(lsof -ti:3000)
```

### ❌ Error: Flutter no encuentra dispositivo

**Problema:** No hay dispositivos/emuladores disponibles

**Solución:**
```bash
# Ver dispositivos disponibles
flutter devices

# Si no hay emuladores, inicia uno:
flutter emulators --launch Pixel_8_Pro

# O desde Android Studio
# Tools > Device Manager > Create/Start emulator
```

---

## 📊 COMANDOS ÚTILES

### Backend

```bash
# Iniciar en modo desarrollo (con watch)
cd apps/backend
npm run start:dev

# Iniciar en modo producción
npm run start:prod

# Ver logs
npm run start:dev  # Los logs aparecen en consola

# Reinstalar dependencias
cd apps/backend
npm install
```

### Frontend

```bash
# Instalar dependencias
cd apps/frontend
flutter pub get

# Ejecutar en dispositivo específico
flutter run -d emulator-5554

# Hot reload (presiona 'r' en la terminal mientras la app corre)
# Hot restart (presiona 'R' en la terminal)

# Limpiar build
flutter clean
flutter pub get

# Ver dispositivos disponibles
flutter devices

# Ver emuladores disponibles
flutter emulators
```

---

## 🎯 ESTRUCTURA DE COMANDOS RÁPIDOS

### Desde la raíz del proyecto:

```bash
# Iniciar solo backend
npm run dev:backend-only

# Iniciar solo admin web (opcional)
npm run dev:admin-only

# Iniciar solo frontend
npm run dev:frontend-only

# Iniciar backend + admin
npm run dev:backend-admin

# Iniciar TODO (backend + admin + frontend)
npm run dev
```

---

## ✅ CHECKLIST DE INICIO

- [ ] PostgreSQL corriendo (Docker o local)
- [ ] Redis corriendo (Docker o local)
- [ ] Variables de entorno configuradas en backend
- [ ] Backend iniciado en puerto 3000
- [ ] Documentación API accesible en `/api/docs`
- [ ] Frontend instalado (`flutter pub get`)
- [ ] Emulador/dispositivo conectado
- [ ] Frontend corriendo y conectado al backend

---

## 🎉 ¡LISTO!

Una vez que hayas completado todos los pasos:

✅ **Backend:** `http://localhost:3000`  
✅ **API Docs:** `http://localhost:3000/api/docs`  
✅ **Frontend:** Corriendo en tu emulador/dispositivo  

**¡Ya puedes usar tu aplicación de música!** 🎵

---

*Última actualización: $(date)*
