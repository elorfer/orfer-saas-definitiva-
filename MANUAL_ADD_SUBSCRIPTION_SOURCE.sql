-- Ejecutar esto manualmente en tu cliente SQL (pgAdmin, DBeaver, etc.)
-- O pégalo en la consola SQL de cualquier herramienta de base de datos

-- 1. Agregar columna si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'subscription_source'
    ) THEN
        ALTER TABLE users 
        ADD COLUMN subscription_source VARCHAR(20) DEFAULT 'manual';
        
        RAISE NOTICE 'Columna subscription_source agregada';
    ELSE
        RAISE NOTICE 'Columna subscription_source ya existe';
    END IF;
END $$;

-- 2. Actualizar usuarios existentes con RevenueCat
UPDATE users 
SET subscription_source = 'revenuecat' 
WHERE revenuecat_customer_id IS NOT NULL
AND (subscription_source IS NULL OR subscription_source = 'manual');

-- 3. Verificar resultado
SELECT 
    COUNT(*) FILTER (WHERE subscription_source = 'revenuecat') as revenuecat_users,
    COUNT(*) FILTER (WHERE subscription_source = 'manual') as manual_users,
    COUNT(*) as total_users
FROM users;

-- 4. Ver algunos ejemplos
SELECT 
    id, 
    email, 
    subscription_source,
    CASE 
        WHEN revenuecat_customer_id IS NOT NULL THEN 'Sí'
        ELSE 'No'
    END as has_revenuecat
FROM users
LIMIT 10;
