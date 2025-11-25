const { Client } = require('pg');
require('dotenv').config({ path: '../../.env' });

const client = new Client({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_DATABASE || 'vintage_music',
  user: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'vintage_password_2024',
});

async function fixMotor24Songs() {
  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos');

    const artistName = 'MOTOR 24';

    console.log(`\n🎤 Buscando artistas "${artistName}":`);
    console.log('═══════════════════════════════════════════════════════════');
    const artistsRes = await client.query(
      `SELECT a.id, a."stageName", a."userId", a."createdAt", 
              COUNT(s.id) FILTER (WHERE s.artist_id = a.id OR s."artistId" = a.id) as song_count
       FROM artists a
       LEFT JOIN songs s ON (s.artist_id = a.id OR s."artistId" = a.id)
       WHERE a."stageName" ILIKE $1 OR a.name ILIKE $1
       GROUP BY a.id, a."stageName", a."userId", a."createdAt"
       ORDER BY a."createdAt" ASC`,
      [`%${artistName}%`]
    );

    if (artistsRes.rows.length === 0) {
      console.log(`❌ No se encontraron artistas con el nombre "${artistName}".`);
      await client.end();
      return;
    }

    if (artistsRes.rows.length === 1) {
      console.log(`✅ Solo hay un artista "${artistName}". No hay duplicados.`);
      await client.end();
      return;
    }

    console.log(`\n⚠️ Se encontraron ${artistsRes.rows.length} artistas con el nombre "${artistName}":`);
    console.log('═══════════════════════════════════════════════════════════');
    
    let artistToKeep = null;
    let artistsToDelete = [];

    for (const artist of artistsRes.rows) {
      console.log(`\n${artistsRes.rows.indexOf(artist) + 1}. ${artist.stageName}`);
      console.log(`   ID: ${artist.id}`);
      console.log(`   User ID: ${artist.userId || 'N/A'}`);
      console.log(`   Canciones: ${artist.song_count}`);
      console.log(`   Creado: ${artist.createdAt}`);

      // Priorizar el artista con canciones o el más antiguo si ambos tienen 0 canciones
      if (parseInt(artist.song_count, 10) > 0) {
        if (!artistToKeep) {
          artistToKeep = artist;
        }
      } else if (!artistToKeep) {
        artistToKeep = artist;
      } else {
        artistsToDelete.push(artist);
      }
    }

    if (!artistToKeep) {
      console.log('\n❌ No se pudo determinar qué artista mantener.');
      await client.end();
      return;
    }

    console.log(`\n🔧 Solución:`);
    console.log(`   ✅ Artista a mantener: ${artistToKeep.stageName} (ID: ${artistToKeep.id})`);
    console.log(`   ❌ Artistas a eliminar: ${artistsToDelete.length}`);

    // Mover canciones del artista duplicado al artista correcto
    for (const artistToDelete of artistsToDelete) {
      console.log(`\n📀 Moviendo canciones de "${artistToDelete.stageName}" (ID: ${artistToDelete.id}) a "${artistToKeep.stageName}" (ID: ${artistToKeep.id})...`);
      
      // Buscar canciones asociadas al artista duplicado
      const songsToMove = await client.query(
        `SELECT id, title, artist_id, "artistId" FROM songs 
         WHERE artist_id = $1 OR "artistId" = $1`,
        [artistToDelete.id]
      );

      if (songsToMove.rows.length > 0) {
        console.log(`   Encontradas ${songsToMove.rows.length} canciones para mover:`);
        for (const song of songsToMove.rows) {
          console.log(`     - "${song.title}"`);
          
          // Actualizar artist_id y artistId
          await client.query(
            `UPDATE songs SET artist_id = $1, "artistId" = $1 WHERE id = $2`,
            [artistToKeep.id, song.id]
          );
        }
        console.log(`   ✅ Canciones movidas correctamente`);
      } else {
        console.log(`   ℹ️ No hay canciones para mover`);
      }

      // Eliminar el artista duplicado
      console.log(`\n🗑️ Eliminando artista duplicado "${artistToDelete.stageName}" (ID: ${artistToDelete.id})...`);
      await client.query(`DELETE FROM artists WHERE id = $1`, [artistToDelete.id]);
      console.log(`   ✅ Artista eliminado`);
    }

    // Verificar resultado final
    console.log(`\n✅ Verificación final:`);
    console.log('═══════════════════════════════════════════════════════════');
    const finalSongs = await client.query(
      `SELECT id, title, status FROM songs 
       WHERE artist_id = $1 OR "artistId" = $1 
       ORDER BY "createdAt" DESC`,
      [artistToKeep.id]
    );
    console.log(`Artista: ${artistToKeep.stageName} (ID: ${artistToKeep.id})`);
    console.log(`Canciones: ${finalSongs.rows.length}`);
    if (finalSongs.rows.length > 0) {
      finalSongs.rows.forEach((song, index) => {
        console.log(`   ${index + 1}. "${song.title}" (Status: ${song.status})`);
      });
    }

    console.log(`\n✅ Problema resuelto. Ahora solo existe un artista "${artistName}" con ID: ${artistToKeep.id}`);

  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

fixMotor24Songs();






