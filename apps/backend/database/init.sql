-- Script de inicialización de la base de datos Vintage Music
-- Este archivo se ejecuta automáticamente cuando se crea el contenedor de PostgreSQL

-- Crear extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Crear esquema si no existe
CREATE SCHEMA IF NOT EXISTS vintage_music;

-- Configurar permisos
GRANT ALL PRIVILEGES ON DATABASE vintage_music TO vintage_user;
GRANT ALL PRIVILEGES ON SCHEMA vintage_music TO vintage_user;

-- La tabla se creará automáticamente mediante TypeORM
-- cuando se ejecute la aplicación por primera vez




