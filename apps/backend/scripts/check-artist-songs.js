const { Client } = require('pg');

const client = new Client({
  host: 'localhost',
  port: 5432,
  database: 'vintage_music',
  user: 'vintage_user',
  password: 'vintage_password_2024'
});

async function checkArtistSongs() {
  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos\n');

    // Buscar el artista "la meje"
    const artistResult = await client.query(`
      SELECT id, stage_name, name, user_id
      FROM artists
      WHERE LOWER(stage_name) LIKE '%meje%' OR LOWER(name) LIKE '%meje%'
      LIMIT 5
    `);

    console.log('🎤 Artistas encontrados con "meje":');
    console.log('═══════════════════════════════════════════════════════════');
    artistResult.rows.forEach((artist, index) => {
      console.log(`${index + 1}. ${artist.stage_name || artist.name || 'Sin nombre'}`);
      console.log(`   ID: ${artist.id}`);
      console.log(`   User ID: ${artist.user_id || 'N/A'}`);
      console.log('');
    });

    if (artistResult.rows.length === 0) {
      console.log('❌ No se encontraron artistas con "meje" en el nombre\n');
      await client.end();
      return;
    }

    // Para cada artista, buscar sus canciones
    for (const artist of artistResult.rows) {
      console.log(`\n📀 Canciones para "${artist.stage_name || artist.name}" (ID: ${artist.id}):`);
      console.log('═══════════════════════════════════════════════════════════');
      
      const songsResult = await client.query(`
        SELECT 
          s.id, 
          s.title, 
          s.status, 
          s.artist_id,
          s.created_at
        FROM songs s
        WHERE s.artist_id = $1
        ORDER BY s.created_at DESC
      `, [artist.id]);

      if (songsResult.rows.length === 0) {
        console.log('   ❌ No hay canciones con este artist_id');
      } else {
        songsResult.rows.forEach((song, index) => {
          console.log(`   ${index + 1}. "${song.title}"`);
          console.log(`      Status: ${song.status}`);
          console.log(`      Artist ID en canción: ${song.artist_id}`);
          console.log(`      Fecha: ${song.created_at}`);
          console.log('');
        });
      }

      // También buscar canciones que podrían tener un artistId diferente
      const allSongsResult = await client.query(`
        SELECT 
          s.id, 
          s.title, 
          s.status, 
          s.artist_id,
          a.stage_name as artist_name,
          a.id as artist_db_id
        FROM songs s
        LEFT JOIN artists a ON s.artist_id = a.id
        WHERE LOWER(s.title) LIKE '%caca%'
        ORDER BY s.created_at DESC
        LIMIT 5
      `);

      if (allSongsResult.rows.length > 0) {
        console.log(`\n🔍 Canciones con título "CACA":`);
        console.log('═══════════════════════════════════════════════════════════');
        allSongsResult.rows.forEach((song, index) => {
          console.log(`${index + 1}. "${song.title}"`);
          console.log(`   Status: ${song.status}`);
          console.log(`   Artist ID en canción: ${song.artist_id}`);
          console.log(`   Artista en BD: ${song.artist_name || 'N/A'} (ID: ${song.artist_db_id || 'N/A'})`);
          console.log(`   ¿Coincide? ${song.artist_id === artist.id ? '✅ SÍ' : '❌ NO'}`);
          console.log('');
        });
      }
    }

    await client.end();
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

checkArtistSongs();



