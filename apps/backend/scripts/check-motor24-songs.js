const { Client } = require('pg');
require('dotenv').config({ path: '../../.env' });

const client = new Client({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_DATABASE || 'vintage_music',
  user: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'vintage_password_2024',
});

async function checkMotor24Songs() {
  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos');

    const artistName = 'MOTOR 24';

    console.log(`\n🎤 Buscando artista "${artistName}":`);
    console.log('═══════════════════════════════════════════════════════════');
    const artistsRes = await client.query(
      `SELECT id, "stageName", "userId" FROM artists WHERE "stageName" ILIKE $1 OR name ILIKE $1 ORDER BY "createdAt" DESC`,
      [`%${artistName}%`]
    );

    if (artistsRes.rows.length === 0) {
      console.log(`❌ Artista "${artistName}" no encontrado.`);
      await client.end();
      return;
    }

    for (const artist of artistsRes.rows) {
      console.log(`\n${artistsRes.rows.indexOf(artist) + 1}. ${artist.stageName}`);
      console.log(`   ID: ${artist.id}`);
      console.log(`   User ID: ${artist.userId || 'N/A'}`);

      console.log(`\n📀 Canciones para "${artist.stageName}" (ID: ${artist.id}):`);
      console.log('═══════════════════════════════════════════════════════════');
      
      // Buscar canciones con artist_id
      const songsRes1 = await client.query(
        `SELECT id, title, status, artist_id, "createdAt" FROM songs WHERE artist_id = $1 ORDER BY "createdAt" DESC`,
        [artist.id]
      );

      // Buscar canciones con artistId (camelCase)
      const songsRes2 = await client.query(
        `SELECT id, title, status, "artistId", "createdAt" FROM songs WHERE "artistId" = $1 ORDER BY "createdAt" DESC`,
        [artist.id]
      );

      const allSongs = [...songsRes1.rows, ...songsRes2.rows.filter(s => !songsRes1.rows.some(s1 => s1.id === s.id))];

      if (allSongs.length === 0) {
        console.log('   ❌ No hay canciones asociadas a este artista');
      } else {
        allSongs.forEach((song, index) => {
          console.log(`   ${index + 1}. "${song.title}"`);
          console.log(`      Status: ${song.status}`);
          console.log(`      Artist ID en canción: ${song.artist_id || song.artistId}`);
          console.log(`      Fecha: ${song.createdAt}`);
          console.log('');
        });
      }

      // Verificar todas las canciones en la BD
      console.log(`\n🔍 Todas las canciones en la base de datos (últimas 10):`);
      console.log('═══════════════════════════════════════════════════════════');
      const allSongsRes = await client.query(
        `SELECT s.id, s.title, s.status, s.artist_id, s."artistId", a."stageName" as artist_name 
         FROM songs s 
         LEFT JOIN artists a ON (s.artist_id = a.id OR s."artistId" = a.id)
         ORDER BY s."createdAt" DESC 
         LIMIT 10`
      );
      
      if (allSongsRes.rows.length === 0) {
        console.log('   No hay canciones en la base de datos.');
      } else {
        allSongsRes.rows.forEach((song, index) => {
          console.log(`   ${index + 1}. "${song.title}"`);
          console.log(`      Artista: ${song.artist_name || 'N/A'}`);
          console.log(`      Status: ${song.status}`);
          console.log(`      artist_id: ${song.artist_id || 'NULL'}`);
          console.log(`      artistId: ${song.artistId || 'NULL'}`);
          console.log('');
        });
      }
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

checkMotor24Songs();






