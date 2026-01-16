# Usar Node 16 basado en Debian Bullseye (OpenSSL 1.1.1)
FROM node:16-bullseye

# Crear directorio de trabajo
WORKDIR /app

# Instalar dependencias globales necesarias
RUN npm install -g @nestjs/cli

# Copiar archivos de definición de dependencias
COPY package*.json ./
COPY apps/backend/package*.json ./apps/backend/
COPY apps/admin/package*.json ./apps/admin/
# (Si tienes más apps o packages, añádelos aquí)

# Instalar dependencias
RUN npm install

# Copiar el código fuente
COPY . .

# Construir el backend
RUN npm run build:backend

# Exponer el puerto
EXPOSE 3001

# Comando de inicio
CMD ["node", "apps/backend/dist/main"]
