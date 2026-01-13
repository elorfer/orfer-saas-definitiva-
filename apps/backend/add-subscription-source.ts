import { DataSource } from 'typeorm';
import { config } from 'dotenv';

// Cargar variables de entorno
config({ path: '.env' });

async function addSubscriptionSourceColumn() {
    // Crear conexión temporal a la BD
    const dataSource = new DataSource({
        type: 'postgres',
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT) || 5432,
        username: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME || 'vintage_music',
    });

    try {
        console.log('🔌 Conectando a la base de datos...');
        await dataSource.initialize();
        console.log('✅ Conectado exitosamente');

        // 1. Agregar columna
        console.log('\n📝 Agregando columna subscription_source...');
        await dataSource.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS subscription_source VARCHAR(20) DEFAULT 'manual';
    `);
        console.log('✅ Columna agregada');

        // 2. Actualizar usuarios con RevenueCat
        console.log('\n🔄 Actualizando usuarios con RevenueCat...');
        const result = await dataSource.query(`
      UPDATE users 
      SET subscription_source = 'revenuecat' 
      WHERE revenuecat_customer_id IS NOT NULL;
    `);
        console.log(`✅ ${result[1]} usuarios actualizados a 'revenuecat'`);

        // 3. Verificar
        console.log('\n🔍 Verificando usuarios...');
        const users = await dataSource.query(`
      SELECT id, email, subscription_source, revenuecat_customer_id 
      FROM users 
      LIMIT 10;
    `);

        console.log('\n📊 Primeros 10 usuarios:');
        console.table(users.map(u => ({
            email: u.email,
            subscription_source: u.subscription_source,
            has_revenuecat: u.revenuecat_customer_id ? 'Sí' : 'No'
        })));

        console.log('\n✅ ¡Migración completada exitosamente!');

    } catch (error) {
        console.error('❌ Error ejecutando migración:', error);
    } finally {
        await dataSource.destroy();
        console.log('\n🔌 Conexión cerrada');
    }
}

// Ejecutar
addSubscriptionSourceColumn();
