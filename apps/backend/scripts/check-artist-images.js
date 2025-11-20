const { Client } = require('pg');
require('dotenv').config({ path: '../../.env' });

const client = new Client({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_DATABASE || 'vintage_music',
  user: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'vintage_password_2024',
});

async function checkArtistImages() {
  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos');

    const artistName = 'la meje';

    const res = await client.query(
      `SELECT id, "stageName", "profilePhotoUrl", "coverPhotoUrl", "isFeatured" FROM artists WHERE "stageName" ILIKE $1`,
      [`%${artistName}%`]
    );

    if (res.rows.length === 0) {
      console.log(`❌ Artista "${artistName}" no encontrado.`);
      await client.end();
      return;
    }

    console.log(`\n🎤 Artista "${artistName}":`);
    console.log('═══════════════════════════════════════════════════════════');
    res.rows.forEach((r) => {
      console.log(`   ID: ${r.id}`);
      console.log(`   Nombre: ${r.stageName}`);
      console.log(`   Foto de perfil: ${r.profilePhotoUrl || 'NULL ❌'}`);
      console.log(`   Portada: ${r.coverPhotoUrl || 'NULL ❌'}`);
      console.log(`   Destacado: ${r.isFeatured ? '✅ SÍ' : '❌ NO'}`);
      console.log('');
    });

    // Verificar si cumple con el filtro del endpoint
    const artist = res.rows[0];
    const hasImage = artist.profilePhotoUrl || artist.coverPhotoUrl;
    console.log(`\n🔍 Análisis para endpoint /public/featured/artists:`);
    console.log(`   ¿Tiene imagen? ${hasImage ? '✅ SÍ' : '❌ NO'}`);
    console.log(`   ¿Aparecerá en la lista? ${hasImage && artist.isFeatured ? '✅ SÍ' : '❌ NO'}`);
    
    if (!hasImage) {
      console.log(`\n💡 SOLUCIÓN: El artista necesita al menos una imagen (perfil o portada) para aparecer.`);
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

checkArtistImages();



