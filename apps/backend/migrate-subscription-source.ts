import { AppDataSource } from './src/database/data-source';

async function addSubscriptionSourceColumn() {
    try {
        console.log('🔌 Conectando a la base de datos...');
        await AppDataSource.initialize();
        console.log('✅ Conectado exitosamente');

        // 1. Agregar columna
        console.log('\n📝 Agregando columna subscription_source...');
        await AppDataSource.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS subscription_source VARCHAR(20) DEFAULT 'manual';
    `);
        console.log('✅ Columna agregada');

        // 2. Actualizar usuarios con RevenueCat
        console.log('\n🔄 Actualizando usuarios con RevenueCat...');
        const result = await AppDataSource.query(`
      UPDATE users 
      SET subscription_source = 'revenuecat' 
      WHERE revenuecat_customer_id IS NOT NULL
      RETURNING id;
    `);
        console.log(`✅ ${result.length} usuarios actualizados a 'revenuecat'`);

        // 3. Verificar
        console.log('\n🔍 Verificando usuarios...');
        const users = await AppDataSource.query(`
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
        console.error('❌ Error ejecutando migración:', error.message);
        console.error(error);
    } finally {
        if (AppDataSource.isInitialized) {
            await AppDataSource.destroy();
            console.log('\n🔌 Conexión cerrada');
        }
    }
}

// Ejecutar
addSubscriptionSourceColumn();
