import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Cargar variables de entorno
dotenv.config();

async function checkUserSubscription() {
    const dataSource = new DataSource({
        type: 'postgres',
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432'),
        username: process.env.DB_USERNAME || 'postgres',
        password: process.env.DB_PASSWORD || 'postgres',
        database: process.env.DB_DATABASE || 'struky_dev',
    });

    try {
        await dataSource.initialize();
        console.log('✅ Conectado a la base de datos\n');

        // Buscar usuarios con email que contenga "cami" o "ovalle"
        const users = await dataSource.query(`
      SELECT 
        id,
        email,
        username,
        subscription_status,
        subscription_source,
        subscription_expires_at,
        revenuecat_customer_id,
        is_premium,
        premium_expires_at,
        created_at,
        updated_at
      FROM users 
      WHERE email ILIKE '%cami%' 
         OR email ILIKE '%ovalle%'
         OR first_name ILIKE '%cami%'
      ORDER BY created_at DESC
      LIMIT 5
    `);

        console.log('📊 Usuarios encontrados:', users.length);
        console.log('\n' + '='.repeat(100) + '\n');

        users.forEach((user: any, index: number) => {
            console.log(`Usuario #${index + 1}:`);
            console.log('  ID:', user.id);
            console.log('  Email:', user.email);
            console.log('  Username:', user.username);
            console.log('  Subscription Status:', user.subscription_status);
            console.log('  🔍 Subscription Source:', user.subscription_source || '❌ NULL');
            console.log('  RevenueCat Customer ID:', user.revenuecat_customer_id || '❌ NULL');
            console.log('  Is Premium:', user.is_premium);
            console.log('  Premium Expires At:', user.premium_expires_at);
            console.log('  Subscription Expires At:', user.subscription_expires_at);
            console.log('  Created At:', user.created_at);
            console.log('  Updated At:', user.updated_at);
            console.log('\n' + '-'.repeat(100) + '\n');
        });

        // Estadísticas generales
        const stats = await dataSource.query(`
      SELECT 
        COUNT(*) FILTER (WHERE subscription_source = 'revenuecat') as revenuecat_count,
        COUNT(*) FILTER (WHERE subscription_source = 'manual') as manual_count,
        COUNT(*) FILTER (WHERE subscription_source IS NULL) as null_count,
        COUNT(*) as total_users
      FROM users
    `);

        console.log('📈 Estadísticas Generales:');
        console.log('  Total usuarios:', stats[0].total_users);
        console.log('  RevenueCat:', stats[0].revenuecat_count);
        console.log('  Manual:', stats[0].manual_count);
        console.log('  NULL (sin definir):', stats[0].null_count);

        await dataSource.destroy();
        console.log('\n✅ Consulta completada');
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

checkUserSubscription();
