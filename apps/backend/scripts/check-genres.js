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

async function checkGenres() {
  try {
    await dataSource.initialize();
    console.log('✅ Conectado a la base de datos\n');

    // Consultar total de géneros
    const totalResult = await dataSource.query('SELECT COUNT(*) as total FROM genres');
    const total = parseInt(totalResult[0].total);

    // Consultar todos los géneros con detalles
    const genres = await dataSource.query(`
      SELECT 
        id, 
        name, 
        description, 
        color_hex, 
        created_at 
      FROM genres 
      ORDER BY name ASC
    `);

    console.log('📊 RESULTADOS:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`🎵 Total de géneros creados: ${total}\n`);

    if (genres.length > 0) {
      console.log('📋 Lista de géneros:');
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      genres.forEach((genre, index) => {
        console.log(`${index + 1}. ${genre.name}`);
        if (genre.description) {
          console.log(`   Descripción: ${genre.description}`);
        }
        if (genre.color_hex) {
          console.log(`   Color: ${genre.color_hex}`);
        }
        console.log(`   Creado: ${new Date(genre.created_at).toLocaleDateString()}`);
        console.log('');
      });
    } else {
      console.log('⚠️  No hay géneros creados aún.');
    }

    await dataSource.destroy();
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.code === 'ECONNREFUSED') {
      console.error('\n💡 Asegúrate de que PostgreSQL esté corriendo y las credenciales sean correctas.');
    }
    process.exit(1);
  }
}

checkGenres();











