# 🎵 Vintage Music Streaming

Una aplicación de streaming musical vintage con diseño retro y funcionalidades modernas, construida con las últimas tecnologías y mejores prácticas de desarrollo.

## 🚀 Características

### 🎨 Diseño Vintage
- **Tipografías bold** con Playfair Display e Inter
- **Colores cálidos** inspirados en la era dorada de la música
- **Interfaz retro** con elementos modernos
- **Tema oscuro/claro** adaptable

### 👥 Roles de Usuario
- **👑 Admin**: Panel de administración completo
- **🎤 Artista**: Subida de música y gestión de perfil
- **🎧 Usuario**: Escucha música y crea playlists

### 🛠️ Tecnologías

#### Backend
- **NestJS v11.1.6** - Framework Node.js robusto
- **PostgreSQL** - Base de datos relacional
- **Redis** - Cache y estadísticas en tiempo real
- **JWT** - Autenticación segura
- **AWS S3** - Almacenamiento de archivos
- **HLS** - Streaming de audio
- **Stripe/PayPal** - Procesamiento de pagos

#### Frontend
- **Flutter v3.35.0** - Aplicación móvil multiplataforma
- **Next.js** - Panel de administración web
- **TypeScript** - Tipado estático
- **Tailwind CSS** - Estilos utilitarios

#### Infraestructura
- **Docker** - Containerización
- **GitHub Actions** - CI/CD
- **AWS** - Despliegue en la nube
- **CloudFront** - CDN global

## 📁 Estructura del Proyecto

```
vintage-music-streaming/
├── apps/
│   ├── backend/          # API NestJS
│   ├── admin/            # Panel admin Next.js
│   └── frontend/         # App Flutter
├── .github/
│   └── workflows/        # CI/CD
├── docker-compose.yml    # Desarrollo
├── docker-compose.prod.yml # Producción
└── README.md
```

## 🚀 Inicio Rápido

### Prerrequisitos
- Node.js 20+
- Flutter 3.35.0+
- Docker & Docker Compose
- PostgreSQL 16+
- Redis 7+

### 1. Clonar el Repositorio
```bash
git clone https://github.com/tu-usuario/vintage-music-streaming.git
cd vintage-music-streaming
```

### 2. Configurar Variables de Entorno
```bash
cp env.example .env
# Editar .env con tus configuraciones
```

### 3. Iniciar con Docker
```bash
# Desarrollo
docker-compose up -d

# Producción
docker-compose -f docker-compose.prod.yml up -d
```

### 4. Instalar Dependencias
```bash
# Backend
cd apps/backend
npm install
npm run start:dev

# Admin Panel
cd apps/admin
npm install
npm run dev

# Flutter App
cd apps/frontend
flutter pub get
flutter run
```

## 🔧 Configuración

### Variables de Entorno

#### Backend (.env)
```env
# Base de datos
DATABASE_URL=postgresql://user:password@localhost:5432/vintage_music
REDIS_URL=redis://localhost:6379

# JWT
JWT_SECRET=tu_jwt_secret_super_seguro
JWT_EXPIRES_IN=7d

# AWS S3
AWS_ACCESS_KEY_ID=tu_aws_access_key
AWS_SECRET_ACCESS_KEY=tu_aws_secret_key
AWS_REGION=us-east-1
AWS_S3_BUCKET=tu-bucket-s3

# Pagos
STRIPE_SECRET_KEY=sk_test_tu_stripe_key
PAYPAL_CLIENT_ID=tu_paypal_client_id
```

#### Admin Panel (.env.local)
```env
NEXT_PUBLIC_API_URL=http://localhost:3000
NEXTAUTH_SECRET=tu_nextauth_secret
```

### Base de Datos

El esquema de la base de datos incluye:

- **Usuarios**: Autenticación y perfiles
- **Artistas**: Información de artistas
- **Canciones**: Metadatos de música
- **Playlists**: Colecciones de canciones
- **Estadísticas**: Métricas de streaming
- **Pagos**: Transacciones y suscripciones

## 🎯 Funcionalidades

### Para Usuarios
- ✅ Registro e inicio de sesión
- ✅ Explorar música por género
- ✅ Crear y gestionar playlists
- ✅ Seguir artistas favoritos
- ✅ Historial de reproducción
- ✅ Búsqueda avanzada
- ✅ Modo offline (próximamente)

### Para Artistas
- ✅ Registro como artista
- ✅ Subida de canciones y álbumes
- ✅ Gestión de perfil artístico
- ✅ Estadísticas de reproducción
- ✅ Gestión de seguidores
- ✅ Monetización (próximamente)

### Para Administradores
- ✅ Panel de control completo
- ✅ Gestión de usuarios y artistas
- ✅ Moderación de contenido
- ✅ Analytics y reportes
- ✅ Gestión de pagos
- ✅ Configuración del sistema

## 🧪 Testing

```bash
# Backend
cd apps/backend
npm run test
npm run test:e2e

# Frontend
cd apps/frontend
flutter test

# Admin Panel
cd apps/admin
npm run test
```

## 📦 Despliegue

### Desarrollo
```bash
docker-compose up -d
```

### Staging
```bash
docker-compose -f docker-compose.staging.yml up -d
```

### Producción
```bash
docker-compose -f docker-compose.prod.yml up -d
```

### AWS ECS
```bash
# Configurar AWS CLI
aws configure

# Desplegar stack
aws cloudformation deploy --template-file infrastructure/ecs-stack.yml
```

## 📊 Monitoreo

- **Prometheus**: Métricas del sistema
- **Grafana**: Dashboards visuales
- **Logs**: Centralizados con ELK Stack
- **Alertas**: Notificaciones automáticas

## 🔒 Seguridad

- **Autenticación JWT** con refresh tokens
- **Encriptación bcrypt** para contraseñas
- **Rate limiting** para prevenir abuso
- **CORS** configurado correctamente
- **Validación** de entrada en todos los endpoints
- **HTTPS** obligatorio en producción

## 🤝 Contribución

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📝 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.

## 👥 Equipo

- **Desarrollador Principal**: [Tu Nombre](https://github.com/tu-usuario)
- **Diseñador UI/UX**: [Diseñador](https://github.com/disenador)
- **DevOps**: [DevOps](https://github.com/devops)

## 📞 Soporte

- **Email**: support@vintagemusic.com
- **Discord**: [Servidor de la Comunidad](https://discord.gg/vintagemusic)
- **Documentación**: [docs.vintagemusic.com](https://docs.vintagemusic.com)

## 🎉 Agradecimientos

- Inspirado en las grandes plataformas de streaming
- Diseño vintage inspirado en la era dorada de la música
- Comunidad de desarrolladores de código abierto

---

**¡Disfruta creando música vintage! 🎵✨**









