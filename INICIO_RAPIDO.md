# 🎵 Vintage Music - Inicio Rápido

## 🚀 Comandos de Inicio

### **Opción 1: Todo junto (Recomendado)**
```bash
npm run dev
```
**Inicia:** Backend + Admin + Flutter

### **Opción 2: Solo Backend + Admin**
```bash
npm run dev:backend-admin
```
**Inicia:** Backend + Admin Panel

### **Opción 3: Solo Backend con Admin integrado**
```bash
cd apps/backend
npm run start:dev:with-admin
```
**Inicia:** Backend que automáticamente inicia el Admin

### **Opción 4: Servicios individuales**
```bash
# Solo Backend
npm run dev:backend-only

# Solo Admin
npm run dev:admin-only

# Solo Flutter
npm run dev:frontend-only
```

## 🌐 URLs de Acceso

| Servicio | URL | Descripción |
|----------|-----|-------------|
| **Backend API** | http://localhost:3000 | API REST + Documentación |
| **Admin Panel** | http://localhost:3002 | Panel de administración |
| **Flutter App** | Emulador Android | Aplicación móvil |

## 📋 Requisitos Previos

1. **Node.js** >= 18.0.0
2. **Flutter** instalado
3. **Docker** (opcional, para base de datos)

## 🔧 Configuración Inicial

```bash
# Instalar dependencias
npm run setup

# Iniciar servicios
npm run dev
```

## 🐳 Con Docker

```bash
# Iniciar base de datos
docker-compose up -d postgres redis

# Iniciar aplicación
npm run dev:backend-admin
```

## 📱 Desarrollo

- **Backend**: Se reinicia automáticamente al cambiar archivos
- **Admin**: Hot reload activado
- **Flutter**: Hot reload con 'r' en terminal

## 🛠️ Comandos Útiles

```bash
# Ver logs
docker-compose logs -f

# Parar servicios
docker-compose down

# Reinstalar dependencias
npm run setup
```

---

**¡Listo para desarrollar!** 🎉


