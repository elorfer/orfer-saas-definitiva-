import { DataSource } from 'typeorm';
import 'dotenv/config';

async function checkPlayHistory() {
    const dataSource = new DataSource({
        type: 'postgres',
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432'),
        username: process.env.DB_USERNAME || 'postgres',
        password: process.env.DB_PASSWORD || 'postgres',
        database: process.env.DB_NAME || 'vintage_music',
        ssl: false,
    });

    try {
        await dataSource.initialize();
        console.log('✅ Conectado a la base de datos\n');

        // Contar registros totales
        const totalResult = await dataSource.query('SELECT COUNT(*) as total FROM play_history');
        console.log(`📊 Total registros en play_history: ${totalResult[0].total}`);

        // Registros de los últimos 7 días
        const weekResult = await dataSource.query(`
      SELECT COUNT(*) as total FROM play_history 
      WHERE played_at >= NOW() - INTERVAL '7 days'
    `);
        console.log(`📊 Registros últimos 7 días: ${weekResult[0].total}`);

        // Registros de hoy
        const todayResult = await dataSource.query(`
      SELECT COUNT(*) as total FROM play_history 
      WHERE DATE(played_at) = CURRENT_DATE
    `);
        console.log(`📊 Registros de HOY: ${todayResult[0].total}`);

        // Últimos 5 registros
        const recentResult = await dataSource.query(`
      SELECT user_id, song_id, played_at, duration_played 
      FROM play_history 
      ORDER BY played_at DESC 
      LIMIT 5
    `);
        console.log('\n📋 Últimos 5 registros:');
        recentResult.forEach((row: any, i: number) => {
            console.log(`   ${i + 1}. User: ${row.user_id.substring(0, 8)}... | Song: ${row.song_id.substring(0, 8)}... | ${row.played_at} | ${row.duration_played}s`);
        });

    } catch (error: any) {
        console.error('❌ Error:', error.message);
    } finally {
        await dataSource.destroy();
    }
}

checkPlayHistory();
