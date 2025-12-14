const { DataSource } = require('typeorm');
const { config } = require('dotenv');
const path = require('path');

// Cargar variables de entorno
config({ path: path.join(__dirname, '../.env') });
config({ path: path.join(__dirname, '../.env.local') });

const dataSource = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL || 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
  synchronize: false,
  logging: false,
});

async function checkSongGenres() {
  try {
    await dataSource.initialize();
    console.log('✅ Conectado a la base de datos\n');

    // Consultar géneros únicos usados en canciones
    const songGenres = await dataSource.query(`
      SELECT DISTINCT 
        unnest(string_to_array(genres, ',')) as genre_name,
        COUNT(*) as song_count
      FROM songs 
      WHERE genres IS NOT NULL 
        AND genres != ''
        AND status = 'published'
      GROUP BY genre_name
      ORDER BY song_count DESC, genre_name ASC
    `);

    // Consultar géneros de la tabla genres
    const dbGenres = await dataSource.query(`
      SELECT name FROM genres ORDER BY name ASC
    `);

    console.log('📊 ANÁLISIS DE GÉNEROS EN EL ALGORITMO:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    console.log('🎵 Géneros definidos en la tabla GENRES:');
    if (dbGenres.length > 0) {
      dbGenres.forEach((g, i) => {
        console.log(`   ${i + 1}. ${g.name}`);
      });
    } else {
      console.log('   ⚠️  No hay géneros en la tabla');
    }

    console.log('\n🎼 Géneros usados en las CANCIONES (que el algoritmo busca):');
    if (songGenres.length > 0) {
      songGenres.forEach((sg, i) => {
        const genreName = sg.genre_name.trim();
        const isInDb = dbGenres.some(g => g.name.toLowerCase() === genreName.toLowerCase());
        const indicator = isInDb ? '✅' : '⚠️';
        console.log(`   ${i + 1}. ${indicator} ${genreName} (${sg.song_count} canción${sg.song_count !== 1 ? 'es' : ''})`);
      });
    } else {
      console.log('   ⚠️  No hay géneros en las canciones');
    }

    console.log('\n📝 CONCLUSIÓN:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('El algoritmo busca géneros en el campo "genres" (array de strings)');
    console.log('de las canciones, NO en la tabla "genres".');
    console.log('\nPara que el algoritmo use tus géneros definidos:');
    console.log('1. Las canciones deben tener esos nombres en el campo "genres"');
    console.log('2. Los nombres deben coincidir (case-insensitive)');

    await dataSource.destroy();
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

checkSongGenres();























