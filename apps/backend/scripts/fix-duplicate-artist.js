const { Client } = require('pg');

const client = new Client({
  host: 'localhost',
  port: 5432,
  database: 'vintage_music',
  user: 'vintage_user',
  password: 'vintage_password_2024'
});

async function fixDuplicateArtist() {
  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos\n');

    // Buscar artistas duplicados con "la meje"
    const artistsResult = await client.query(`
      SELECT id, stage_name, name, user_id, created_at,
        (SELECT COUNT(*) FROM songs WHERE artist_id = artists.id) as song_count
      FROM artists
      WHERE LOWER(stage_name) LIKE '%meje%' OR LOWER(name) LIKE '%meje%'
      ORDER BY created_at ASC
    `);

    console.log('🎤 Artistas encontrados:');
    console.log('═══════════════════════════════════════════════════════════');
    artistsResult.rows.forEach((artist, index) => {
      console.log(`${index + 1}. ${artist.stage_name || artist.name || 'Sin nombre'}`);
      console.log(`   ID: ${artist.id}`);
      console.log(`   User ID: ${artist.user_id || 'N/A'}`);
      console.log(`   Canciones: ${artist.song_count}`);
      console.log(`   Creado: ${artist.created_at}`);
      console.log('');
    });

    if (artistsResult.rows.length < 2) {
      console.log('✅ No hay artistas duplicados\n');
      await client.end();
      return;
    }

    // Identificar el artista con canciones y el sin canciones
    const artistWithSongs = artistsResult.rows.find(a => parseInt(a.song_count) > 0);
    const artistWithoutSongs = artistsResult.rows.find(a => parseInt(a.song_count) === 0);

    if (!artistWithSongs || !artistWithoutSongs) {
      console.log('⚠️ No se puede determinar cuál artista eliminar\n');
      await client.end();
      return;
    }

    console.log(`\n🔧 Solución:`);
    console.log(`   ✅ Artista a mantener: ${artistWithSongs.stage_name || artistWithSongs.name} (ID: ${artistWithSongs.id})`);
    console.log(`   ❌ Artista a eliminar: ${artistWithoutSongs.stage_name || artistWithoutSongs.name} (ID: ${artistWithoutSongs.id})`);
    console.log('');

    // Verificar que el artista sin canciones no tenga relaciones
    const relationsCheck = await client.query(`
      SELECT 
        (SELECT COUNT(*) FROM albums WHERE artist_id = $1) as albums,
        (SELECT COUNT(*) FROM artist_followers WHERE artist_id = $1) as followers,
        (SELECT COUNT(*) FROM playlists WHERE user_id = (SELECT user_id FROM artists WHERE id = $1)) as playlists
    `, [artistWithoutSongs.id]);

    const hasRelations = 
      parseInt(relationsCheck.rows[0].albums) > 0 ||
      parseInt(relationsCheck.rows[0].followers) > 0 ||
      parseInt(relationsCheck.rows[0].playlists) > 0;

    if (hasRelations) {
      console.log('⚠️ El artista tiene relaciones. No se puede eliminar automáticamente.');
      console.log('   Álbumes:', relationsCheck.rows[0].albums);
      console.log('   Seguidores:', relationsCheck.rows[0].followers);
      console.log('   Playlists:', relationsCheck.rows[0].playlists);
      await client.end();
      return;
    }

    // Eliminar el artista duplicado sin canciones
    console.log('🗑️ Eliminando artista duplicado...');
    await client.query('DELETE FROM artists WHERE id = $1', [artistWithoutSongs.id]);
    console.log(`✅ Artista eliminado: ${artistWithoutSongs.id}`);
    console.log(`\n✅ Problema resuelto. Ahora solo existe un artista "la meje" con ID: ${artistWithSongs.id}`);

    await client.end();
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

fixDuplicateArtist();



