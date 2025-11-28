const { DataSource } = require('typeorm');

// Configuración de la base de datos
const dataSource = new DataSource({
  type: 'postgres',
  host: 'localhost',
  port: 5432,
  username: 'vintage_user',
  password: 'vintage_password_2024',
  database: 'vintage_music',
  entities: [],
  synchronize: false,
});

async function checkFeaturedSongs() {
  try {
    await dataSource.initialize();
    console.log('✅ Conectado a la base de datos');
    
    // Verificar canciones destacadas usando query raw
    const featuredSongs = await dataSource.query(`
      SELECT s.id, s.title, s.file_url, s.cover_art_url, s.is_featured, a.stage_name
      FROM songs s
      LEFT JOIN artists a ON s.artist_id = a.id
      WHERE s.is_featured = true AND s.status = 'published'
      ORDER BY s.created_at DESC
    `);
    
    console.log(`\n⭐ Canciones destacadas encontradas: ${featuredSongs.length}`);
    featuredSongs.forEach((song, index) => {
      console.log(`${index + 1}. ${song.title} - ${song.stage_name || 'Sin artista'}`);
      console.log(`   URL: ${song.file_url}`);
      console.log(`   Carátula: ${song.cover_art_url || 'Sin carátula'}`);
    });
    
    // Si no hay canciones destacadas, marcar algunas
    if (featuredSongs.length === 0) {
      console.log('\n🔄 No hay canciones destacadas. Marcando algunas...');
      
      const allSongs = await dataSource.query(`
        SELECT s.id, s.title, s.file_url, s.cover_art_url, a.stage_name
        FROM songs s
        LEFT JOIN artists a ON s.artist_id = a.id
        WHERE s.status = 'published'
        ORDER BY s.created_at DESC
        LIMIT 5
      `);
      
      console.log(`📝 Canciones disponibles: ${allSongs.length}`);
      
      if (allSongs.length > 0) {
        // Marcar las primeras 3 como destacadas
        for (let i = 0; i < Math.min(3, allSongs.length); i++) {
          await dataSource.query(`
            UPDATE songs SET is_featured = true WHERE id = $1
          `, [allSongs[i].id]);
          console.log(`✅ Marcada como destacada: ${allSongs[i].title}`);
        }
        
        console.log('\n🔄 Verificando cambios...');
        const newFeaturedSongs = await dataSource.query(`
          SELECT s.id, s.title, s.file_url, s.cover_art_url, a.stage_name
          FROM songs s
          LEFT JOIN artists a ON s.artist_id = a.id
          WHERE s.is_featured = true AND s.status = 'published'
        `);
        
        console.log(`✅ Ahora hay ${newFeaturedSongs.length} canciones destacadas`);
      }
    }
    
    await dataSource.destroy();
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

checkFeaturedSongs();


