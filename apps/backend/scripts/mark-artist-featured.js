const { Client } = require('pg');

const client = new Client({
  host: 'localhost',
  port: 5432,
  database: 'vintage_music',
  user: 'vintage_user',
  password: 'vintage_password_2024'
});

async function markArtistFeatured() {
  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos\n');

    // Buscar el artista "la meje" con canciones
    const artistResult = await client.query(`
      SELECT id, stage_name, name, is_featured,
        (SELECT COUNT(*) FROM songs WHERE artist_id = artists.id AND status = 'published') as published_songs
      FROM artists
      WHERE id = '6cdc1f52-3937-4d63-ac31-5c923ea3fc0b'
    `);

    if (artistResult.rows.length === 0) {
      console.log('❌ Artista no encontrado\n');
      await client.end();
      return;
    }

    const artist = artistResult.rows[0];
    console.log('🎤 Artista encontrado:');
    console.log(`   Nombre: ${artist.stage_name || artist.name}`);
    console.log(`   ID: ${artist.id}`);
    console.log(`   Es destacado: ${artist.is_featured}`);
    console.log(`   Canciones publicadas: ${artist.published_songs}`);
    console.log('');

    if (!artist.is_featured) {
      console.log('🔧 Marcando artista como destacado...');
      await client.query('UPDATE artists SET is_featured = true WHERE id = $1', [artist.id]);
      console.log('✅ Artista marcado como destacado\n');
    } else {
      console.log('✅ El artista ya está marcado como destacado\n');
    }

    // Verificar que ahora aparezca en la lista de destacados
    const featuredResult = await client.query(`
      SELECT id, stage_name, name, is_featured
      FROM artists
      WHERE is_featured = true
      ORDER BY created_at DESC
      LIMIT 10
    `);

    console.log('⭐ Artistas destacados:');
    console.log('═══════════════════════════════════════════════════════════');
    featuredResult.rows.forEach((a, index) => {
      console.log(`${index + 1}. ${a.stage_name || a.name} (ID: ${a.id})`);
    });

    await client.end();
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

markArtistFeatured();



