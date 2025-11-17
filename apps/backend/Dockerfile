FROM node:20-alpine

WORKDIR /app

# Instalar dependencias del sistema
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    ffmpeg \
    vips-dev

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar dependencias (incluyendo dev para compilar)
RUN npm install

# Copiar código fuente
COPY . .

# Compilar la aplicación
RUN npm run build

# Exponer puerto
EXPOSE 3000

# Comando de inicio
CMD ["npm", "run", "start:prod"]
