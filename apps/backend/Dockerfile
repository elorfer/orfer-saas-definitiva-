FROM node:20-bullseye-slim

WORKDIR /app

# Instalar dependencias del sistema necesarias para compilar módulos nativos
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    build-essential \
    make \
    g++ \
    ffmpeg \
    libvips-dev \
    curl \
    bash \
    netcat \
    && rm -rf /var/lib/apt/lists/*

# Asegurar node-gyp disponible globalmente para compilaciones nativas (sharp)
RUN npm install -g node-gyp

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar dependencias - usar npm install para Railway (sincroniza automáticamente)
RUN npm install --only=production --unsafe-perm

# Copiar código fuente
COPY . .

# Compilar la aplicación
RUN npm run build

# Exponer puerto (Railway usa PORT env var, pero defaulteamos a 3001)
EXPOSE 3001

# Comando de inicio - Railway maneja las dependencias automáticamente
CMD ["npm", "run", "start:prod"]
