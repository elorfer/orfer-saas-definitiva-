# Vintage Music Admin Panel

Panel de administración profesional para Vintage Music Streaming Platform.

## 🚀 Características

- **Autenticación segura** con NextAuth.js
- **Diseño moderno** con Glassmorphism y animaciones
- **Sistema de logging** profesional
- **Manejo de errores** centralizado
- **Configuración** por entornos (dev/staging/prod)
- **TypeScript** para type safety
- **Responsive** para todos los dispositivos

## 📋 Prerrequisitos

- Node.js 18+ 
- npm o yarn
- PostgreSQL (para backend)
- Redis (opcional, para caché)

## ⚙️ Configuración

### 1. Variables de Entorno

Copia el archivo de ejemplo y configura las variables:

```bash
cp env.example .env.local
```

### Variables Requeridas:

```env
# NextAuth
NEXTAUTH_URL=http://localhost:3002
NEXTAUTH_SECRET=your-secret-key-here

# API
NEXT_PUBLIC_API_URL=http://localhost:3000/api/v1

# Base de datos (opcional para admin directo)
DATABASE_URL=postgresql://user:pass@localhost:5432/vintage_music
```

### 2. Instalación

```bash
# Instalar dependencias
npm install

# Verificar configuración
npm run type-check

# Ejecutar en desarrollo
npm run dev
```

## 🛠️ Scripts Disponibles

```bash
# Desarrollo
npm run dev              # Servidor de desarrollo
npm run type-check       # Verificación de tipos
npm run lint             # Linting
npm run lint:fix         # Linting con auto-fix

# Producción
npm run build            # Build para producción
npm run start:prod       # Servidor de producción
npm run build:analyze    # Build con análisis de bundle

# Testing
npm run test             # Ejecutar tests
npm run test:watch       # Tests en modo watch
npm run test:coverage    # Tests con coverage

# Utilidades
npm run clean            # Limpiar archivos de build
npm run validate         # Validación completa
```

## 🔐 Credenciales de Desarrollo

Para desarrollo, usa estas credenciales:

- **Email:** `admin@vintagemusic.com`
- **Contraseña:** `admin123`

## 🏗️ Arquitectura

```
src/
├── app/                 # Next.js App Router
│   ├── api/            # API Routes
│   ├── dashboard/      # Dashboard pages
│   ├── login/          # Login page
│   └── layout.tsx      # Root layout
├── components/         # React components
├── config/            # Configuration
├── lib/               # Utilities and services
│   ├── auth.ts        # NextAuth configuration
│   ├── logger.ts      # Logging system
│   └── error-handler.ts # Error handling
└── types/             # TypeScript types
```

## 🔧 Configuración por Entornos

### Desarrollo
- Logging detallado
- Hot reload
- Source maps
- Credenciales de prueba

### Producción
- Logging optimizado
- Minificación
- Caché agresivo
- Validación estricta

## 📊 Monitoreo y Logging

El sistema incluye logging profesional con:

- **Niveles de log:** ERROR, WARN, INFO, DEBUG
- **Contexto:** Información contextual para cada log
- **Metadatos:** Datos adicionales estructurados
- **Formato:** JSON en producción, colores en desarrollo

## 🚨 Manejo de Errores

Sistema centralizado de manejo de errores:

- **Errores tipados** con códigos específicos
- **Logging automático** de errores
- **Respuestas consistentes** para el cliente
- **Stack traces** solo en desarrollo

## 🔒 Seguridad

- **Autenticación JWT** con NextAuth.js
- **Rate limiting** configurable
- **Validación de entrada** estricta
- **Sanitización** de datos
- **Headers de seguridad** automáticos

## 🚀 Despliegue

### Docker

```bash
# Build
docker build -t vintage-music-admin .

# Run
docker run -p 3002:3002 vintage-music-admin
```

### Variables de Producción

Asegúrate de configurar:

- `NEXTAUTH_SECRET` (generar con openssl rand -base64 32)
- `NEXTAUTH_URL` (URL de producción)
- `DATABASE_URL` (conexión a BD de producción)
- `REDIS_URL` (para caché y sesiones)

## 📝 Contribución

1. Fork el proyecto
2. Crea una rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -m 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 🆘 Soporte

Para soporte técnico, contacta al equipo de desarrollo o crea un issue en el repositorio.


