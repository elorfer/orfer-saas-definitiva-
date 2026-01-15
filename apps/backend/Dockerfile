# ===================================
# DOCKERFILE OPTIMIZADO PARA RAILWAY
# Actualizado: 2026-01-14 16:54 UTC
# Forzar rebuild - instala TODAS las deps
# ===================================

FROM node:20.11.0-bullseye-slim

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

# Instalar TODAS las dependencias (prod + dev) - NO establecer NODE_ENV aún
RUN npm install --unsafe-perm

# Verificar e instalar Sharp EXPLÍCITAMENTE con libvips
RUN echo "=== INSTALANDO SHARP ===" && \
    npm install sharp@^0.34.5 --verbose --build-from-source && \
    echo "=== VERIFICANDO SHARP ===" && \
    node -e "try { require('sharp'); console.log('✅ Sharp importado correctamente'); } catch(e) { console.log('❌ Error:', e.message); }"

# Copiar código fuente
COPY . .

# Compilar la aplicación (necesita @nestjs/cli de devDependencies)
RUN npm run build

# IMPORTANTE: NO hacer npm prune para mantener Sharp funcionando
# Sharp necesita las librerías de sistema que podrían eliminarse
ENV NODE_ENV=production

# Crear directorio para uploads
RUN mkdir -p uploads/covers uploads/songs uploads/ads/audio uploads/ads/covers

# Exponer puerto (Railway usa PORT env var)
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
    CMD curl -f http://localhost:${PORT:-3001}/api/v1/health || exit 1

# Comando de inicio
CMD ["node", "dist/main.js"]
