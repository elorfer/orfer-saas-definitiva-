const { Client } = require('pg');

const client = new Client({
  host: 'localhost',
  port: 5432,
  database: 'vintage_music',
  user: 'postgres',
  password: 'postgres'
});

async function checkSongs() {
  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos\n');

    // Obtener últimas 10 canciones
    const songsResult = await client.query(`
      SELECT 
        s.id, 
        s.title, 
        s.status, 
        s.artist_id,
        a.stage_name as artist_name
      FROM songs s
      LEFT JOIN artists a ON s.artist_id = a.id
      ORDER BY s.created_at DESC 
      LIMIT 10
    `);

    console.log('📀 Últimas 10 canciones:');
    console.log('═══════════════════════════════════════════════════════════');
    songsResult.rows.forEach((song, index) => {
      console.log(`${index + 1}. "${song.title}"`);
      console.log(`   Status: ${song.status}`);
      console.log(`   Artist ID: ${song.artist_id}`);
      console.log(`   Artist Name: ${song.artist_name || 'N/A'}`);
      console.log('');
    });

    // Verificar canciones por artista
    const artistSongsResult = await client.query(`
      SELECT 
        a.id as artist_id,
        a.stage_name,
        COUNT(s.id) as total_songs,
        COUNT(CASE WHEN s.status = 'published' THEN 1 END) as published_songs
      FROM artists a
      LEFT JOIN songs s ON s.artist_id = a.id
      GROUP BY a.id, a.stage_name
      ORDER BY total_songs DESC
      LIMIT 5
    `);

    console.log('\n🎤 Artistas y sus canciones:');
    console.log('═══════════════════════════════════════════════════════════');
    artistSongsResult.rows.forEach((artist) => {
      console.log(`Artista: ${artist.stage_name || 'N/A'} (ID: ${artist.artist_id})`);
      console.log(`  Total canciones: ${artist.total_songs}`);
      console.log(`  Canciones publicadas: ${artist.published_songs}`);
      console.log('');
    });

    await client.end();
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

checkSongs();






