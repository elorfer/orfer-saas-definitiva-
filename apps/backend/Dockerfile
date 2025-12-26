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

# Instalar dependencias reproduciblemente si existe package-lock, si no usar npm install
RUN if [ -f package-lock.json ]; then \
            echo "package-lock.json found, running npm ci" && npm ci --unsafe-perm; \
        else \
            echo "No package-lock.json, running npm install" && npm install --unsafe-perm; \
        fi

# Copiar código fuente
COPY . .

# Añadir script de espera
RUN mkdir -p /app/scripts && chmod +x /app/scripts/wait-for.sh

# Compilar la aplicación
RUN npm run build

# Exponer puerto correcto usado por la app (3001)
EXPOSE 3001

# Esperar por Postgres y Redis antes de arrancar la app
CMD ["sh", "-c", "./scripts/wait-for.sh postgres 5432 && ./scripts/wait-for.sh redis 6379 && npm run start:prod"]
