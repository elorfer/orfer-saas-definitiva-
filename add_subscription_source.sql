-- Agregar columna subscription_source a la tabla users
-- Ejecutar: psql -U postgres -d vintage_music -f add_subscription_source.sql

-- Agregar columna con default 'manual'
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS subscription_source VARCHAR(20) DEFAULT 'manual';

-- Actualizar usuarios existentes con revenuecatCustomerId
UPDATE users 
SET subscription_source = 'revenuecat' 
WHERE revenuecat_custom_id IS NOT NULL;

-- Crear índice para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_users_subscription_source 
ON users (subscription_source);

-- Verificar
SELECT id, email, subscription_source, revenuecat_customer_id 
FROM users 
LIMIT 10;
