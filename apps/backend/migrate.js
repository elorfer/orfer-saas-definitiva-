const { Client } = require('pg');
require('dotenv').config();

async function migrate() {
    const client = new Client({
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT || 5432,
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME || 'vintage_music',
    });

    try {
        console.log('🔌 Conectando a PostgreSQL...');
        await client.connect();
        console.log('✅ Conectado exitosamente\n');

        // 1. Agregar columna
        console.log('📝 Agregando columna subscription_source...');
        await client.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS subscription_source VARCHAR(20) DEFAULT 'manual';
    `);
        console.log('✅ Columna agregada\n');

        // 2. Actualizar usuarios con RevenueCat
        console.log('🔄 Actualizando usuarios con RevenueCat...');
        const result = await client.query(`
      UPDATE users 
      SET subscription_source = 'revenuecat' 
      WHERE revenuecat_customer_id IS NOT NULL;
    `);
        console.log(`✅ ${result.rowCount} usuarios actualizados a 'revenuecat'\n`);

        // 3. Verificar
        console.log('🔍 Verificando usuarios...');
        const { rows } = await client.query(`
      SELECT id, email, subscription_source, revenuecat_customer_id 
      FROM users 
      LIMIT 10;
    `);

        console.log('\n📊 Primeros 10 usuarios:');
        console.table(rows.map(u => ({
            email: u.email,
            subscription_source: u.subscription_source,
            has_revenuecat: u.revenuecat_customer_id ? 'Sí' : 'No'
        })));

        console.log('\n✅ ¡Migración completada exitosamente!');

    } catch (error) {
        console.error('\n❌ Error:', error.message);
        process.exit(1);
    } finally {
        await client.end();
        console.log('\n🔌 Conexión cerrada');
    }
}

migrate();
