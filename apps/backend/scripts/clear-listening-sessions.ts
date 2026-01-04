import { DataSource } from 'typeorm';
import { config } from 'dotenv';
import * as path from 'path';

// Cargar variables de entorno
config({ path: path.resolve(__dirname, '../../.env') });

async function clearListeningSessions() {
    const dataSource = new DataSource({
        type: 'postgres',
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432'),
        username: process.env.DB_USERNAME || 'postgres',
        password: process.env.DB_PASSWORD || 'postgres',
        database: process.env.DB_DATABASE || 'vintage_music',
        synchronize: false,
    });

    try {
        await dataSource.initialize();
        console.log('✅ Conectado a la base de datos');

        // Limpiar todas las sesiones de escucha
        const result = await dataSource.query('DELETE FROM user_listening_session');
        console.log(`🗑️  Eliminadas ${result[1] || 0} sesiones de escucha`);

        console.log('✅ Sesiones limpiadas. Ahora puedes probar con canciones "frescas"');
    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        await dataSource.destroy();
    }
}

clearListeningSessions();
