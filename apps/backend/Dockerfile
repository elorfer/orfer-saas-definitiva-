# ===================================
# DOCKERFILE OPTIMIZADO PARA RAILWAY
# Actualizado: 2026-01-14 16:54 UTC
# Forzar rebuild - instala TODAS las deps
# ===================================

FROM node:20-bullseye-slim

# Variables de entorno
ENV NODE_ENV=production

WORKDIR /app

# Instalar dependencias del sistema para módulos nativos
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    build-essential \
    make \
    g++ \
    ffmpeg \
    libvips-dev \
    curl \
    bash \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Instalar node-gyp globalmente para compilaciones nativas
RUN npm install -g node-gyp npm@latest

# Copiar package files
COPY package*.json ./

# Instalar TODAS las dependencias primero (prod + dev para build)
RUN npm install --unsafe-perm

# Copiar código fuente
COPY . .

# Compilar la aplicación
RUN npm run build

# Limpiar devDependencies después del build
RUN npm prune --production

# Crear directorio para uploads
RUN mkdir -p uploads/covers uploads/songs uploads/ads/audio uploads/ads/covers

# Exponer puerto (Railway usa PORT env var)
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
    CMD curl -f http://localhost:${PORT:-3001}/api/v1/health || exit 1

# Comando de inicio
CMD ["node", "dist/main.js"]
