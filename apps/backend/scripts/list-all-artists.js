const { Client } = require('pg');

const client = new Client({
  host: 'localhost',
  port: 5432,
  database: 'vintage_music',
  user: 'vintage_user',
  password: 'vintage_password_2024'
});

async function listAllArtists() {
  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos\n');

    // Listar todos los artistas
    const artistsResult = await client.query(`
      SELECT 
        id, 
        stage_name, 
        name, 
        user_id,
        created_at,
        (SELECT COUNT(*) FROM songs WHERE artist_id = artists.id AND status = 'published') as published_songs,
        (SELECT COUNT(*) FROM songs WHERE artist_id = artists.id) as total_songs
      FROM artists
      ORDER BY created_at DESC
      LIMIT 20
    `);

    console.log('🎤 Todos los artistas:');
    console.log('═══════════════════════════════════════════════════════════');
    artistsResult.rows.forEach((artist, index) => {
      console.log(`${index + 1}. ${artist.stage_name || artist.name || 'Sin nombre'}`);
      console.log(`   ID: ${artist.id}`);
      console.log(`   User ID: ${artist.user_id || 'N/A'}`);
      console.log(`   Canciones publicadas: ${artist.published_songs}`);
      console.log(`   Total canciones: ${artist.total_songs}`);
      console.log(`   Creado: ${artist.created_at}`);
      console.log('');
    });

    await client.end();
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

listAllArtists();






