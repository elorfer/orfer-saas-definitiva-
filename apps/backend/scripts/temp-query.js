
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

async function runQuery() {
    try {
        await dataSource.initialize();

        console.log('\n📊 REPORTE DE BASE DE DATOS');
        console.log('==================================================');

        // 1. GÉNEROS
        const songGenres = await dataSource.query(`
      SELECT DISTINCT 
        unnest(string_to_array(genres, ',')) as genre_name,
        COUNT(*) as song_count
      FROM songs 
      WHERE genres IS NOT NULL AND genres != '' AND status = 'published'
      GROUP BY genre_name
      ORDER BY song_count DESC
    `);

        console.log('\n🎵 GÉNEROS (de canciones publicadas):');
        songGenres.forEach(g => {
            console.log(`- ${g.genre_name}: ${g.song_count} canciones`);
        });

        // 2. ARTISTAS (Top 5)
        const artists = await dataSource.query(`
      SELECT stage_name, COUNT(s.id) as count 
      FROM artists a 
      LEFT JOIN songs s ON s.artist_id = a.id 
      GROUP BY a.id 
      ORDER BY count DESC 
      LIMIT 5
    `);

        console.log('\n🎤 TOP ARTISTAS:');
        artists.forEach(a => {
            console.log(`- ${a.stage_name}: ${a.count} canciones`);
        });

        // 3. ÚLTIMAS CANCIONES
        const songs = await dataSource.query(`
      SELECT s.title, s.genres, a.stage_name 
      FROM songs s
      LEFT JOIN artists a ON s.artist_id = a.id
      ORDER BY s.created_at DESC
      LIMIT 10
    `);

        console.log('\n📀 ÚLTIMAS 10 CANCIONES:');
        songs.forEach(s => {
            console.log(`- "${s.title}" (${s.stage_name}) [${s.genres || 'Sin género'}]`);
        });

        await dataSource.destroy();
        process.exit(0);
    } catch (error) {
        console.error(error);
        process.exit(1);
    }
}

runQuery();
