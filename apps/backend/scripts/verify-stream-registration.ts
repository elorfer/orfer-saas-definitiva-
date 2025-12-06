import { Client } from 'pg';
import * as dotenv from 'dotenv';

dotenv.config();

async function verifyStreamRegistration() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL || 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  });

  try {
    await client.connect();
    console.log('🔍 Verificando registro de streams...\n');

    // Verificar streams registrados
    const streamsResult = await client.query(`
      SELECT 
        s.id,
        s.user_id,
        s.song_id,
        s.duration_listened,
        s.created_at,
        so.title as song_title,
        a.stage_name as artist_name
      FROM streams s
      JOIN songs so ON s.song_id = so.id
      JOIN artists a ON so.artist_id = a.id
      ORDER BY s.created_at DESC
      LIMIT 5
    `);

    console.log('📊 Últimos 5 streams registrados:');
    if (streamsResult.rows.length === 0) {
      console.log('   ⚠️  No hay streams registrados aún');
    } else {
      streamsResult.rows.forEach((row, index) => {
        console.log(`\n   ${index + 1}. Stream ID: ${row.id}`);
        console.log(`      Canción: "${row.song_title}"`);
        console.log(`      Artista: ${row.artist_name}`);
        console.log(`      Duración escuchada: ${row.duration_listened}s`);
        console.log(`      Fecha: ${row.created_at}`);
      });
    }

    // Verificar sesiones activas
    const sessionsResult = await client.query(`
      SELECT 
        uls.id,
        uls.user_id,
        uls.song_id,
        uls.max_progress_ms,
        uls.is_stream_validated,
        uls.started_at,
        so.title as song_title
      FROM user_listening_sessions uls
      JOIN songs so ON uls.song_id = so.id
      ORDER BY uls.created_at DESC
      LIMIT 5
    `);

    console.log('\n\n📋 Últimas 5 sesiones de escucha:');
    if (sessionsResult.rows.length === 0) {
      console.log('   ⚠️  No hay sesiones activas');
    } else {
      sessionsResult.rows.forEach((row, index) => {
        console.log(`\n   ${index + 1}. Sesión ID: ${row.id}`);
        console.log(`      Canción: "${row.song_title}"`);
        console.log(`      Progreso máximo: ${(row.max_progress_ms / 1000).toFixed(1)}s`);
        console.log(`      Stream validado: ${row.is_stream_validated ? '✅ Sí' : '❌ No'}`);
        console.log(`      Iniciada: ${row.started_at}`);
      });
    }

    // Verificar contadores de canciones
    const songsCountResult = await client.query(`
      SELECT 
        so.id,
        so.title,
        so.total_streams,
        a.stage_name as artist_name,
        a.total_streams as artist_total_streams
      FROM songs so
      JOIN artists a ON so.artist_id = a.id
      WHERE so.total_streams > 0
      ORDER BY so.total_streams DESC
      LIMIT 5
    `);

    console.log('\n\n🎵 Top 5 canciones por streams:');
    if (songsCountResult.rows.length === 0) {
      console.log('   ⚠️  No hay canciones con streams');
    } else {
      songsCountResult.rows.forEach((row, index) => {
        console.log(`\n   ${index + 1}. "${row.title}" - ${row.artist_name}`);
        console.log(`      Streams de la canción: ${row.total_streams}`);
        console.log(`      Streams totales del artista: ${row.artist_total_streams}`);
      });
    }

    console.log('\n✅ Verificación completada!\n');

  } catch (error: any) {
    console.error('❌ Error:', error.message);
  } finally {
    await client.end();
  }
}

verifyStreamRegistration();




