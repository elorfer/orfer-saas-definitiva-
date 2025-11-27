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

async function fixSongUrls() {
  try {
    await dataSource.initialize();
    console.log('✅ Conectado a la base de datos');
    
    // Buscar canciones con URLs incorrectas (puerto 3000)
    const songsWithWrongUrls = await dataSource.query(`
      SELECT id, title, file_url
      FROM songs
      WHERE file_url LIKE '%localhost:3000%'
      ORDER BY created_at DESC
    `);
    
    console.log(`\n🔍 Canciones con URLs incorrectas encontradas: ${songsWithWrongUrls.length}`);
    
    if (songsWithWrongUrls.length > 0) {
      console.log('\n📝 Corrigiendo URLs...');
      
      for (const song of songsWithWrongUrls) {
        const oldUrl = song.file_url;
        const newUrl = oldUrl.replace('localhost:3000', 'localhost:3001');
        
        await dataSource.query(`
          UPDATE songs SET file_url = $1 WHERE id = $2
        `, [newUrl, song.id]);
        
        console.log(`✅ ${song.title}`);
        console.log(`   Antes: ${oldUrl}`);
        console.log(`   Después: ${newUrl}`);
        console.log('');
      }
      
      console.log(`✅ Se corrigieron ${songsWithWrongUrls.length} URLs de canciones`);
    } else {
      console.log('✅ No se encontraron URLs incorrectas');
    }
    
    // Verificar el resultado
    console.log('\n🔄 Verificando canciones destacadas...');
    const featuredSongs = await dataSource.query(`
      SELECT s.id, s.title, s.file_url, s.cover_art_url, a.stage_name
      FROM songs s
      LEFT JOIN artists a ON s.artist_id = a.id
      WHERE s.is_featured = true AND s.status = 'published'
      ORDER BY s.created_at DESC
    `);
    
    console.log(`\n⭐ Canciones destacadas (${featuredSongs.length}):`);
    featuredSongs.forEach((song, index) => {
      console.log(`${index + 1}. ${song.title} - ${song.stage_name}`);
      console.log(`   Audio: ${song.file_url}`);
      console.log(`   Carátula: ${song.cover_art_url || 'Sin carátula'}`);
      console.log('');
    });
    
    await dataSource.destroy();
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

fixSongUrls();

