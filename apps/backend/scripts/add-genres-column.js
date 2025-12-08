const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function runMigration() {
  // Obtener configuración de la base de datos
  const databaseUrl = process.env.DATABASE_URL;
  
  let client;
  
  if (databaseUrl) {
    client = new Client({ connectionString: databaseUrl });
  } else {
    client = new Client({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      user: process.env.DB_USERNAME || 'vintage_user',
      password: process.env.DB_PASSWORD || 'vintage_password_2024',
      database: process.env.DB_DATABASE || 'vintage_music',
    });
  }

  try {
    console.log('🔌 Conectando a la base de datos...');
    await client.connect();
    console.log('✅ Conectado exitosamente');

    // Leer y ejecutar la migración
    const migrationFile = path.join(__dirname, '../src/database/migrations/add-genres-column-to-songs.sql');
    console.log(`📄 Leyendo archivo: ${migrationFile}`);
    
    if (!fs.existsSync(migrationFile)) {
      console.error(`❌ Archivo no encontrado: ${migrationFile}`);
      process.exit(1);
    }
    
    const sql = fs.readFileSync(migrationFile, 'utf8');
    console.log('📝 Ejecutando migración SQL...\n');
    await client.query(sql);
    console.log('✅ Migración ejecutada con éxito: add-genres-column-to-songs.sql');

    // Verificar que la columna existe
    const result = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'songs' 
      AND column_name = 'genres'
    `);

    if (result.rows.length > 0) {
      console.log('✅ Verificación: La columna genres existe en la tabla songs');
      console.log(`   Tipo de dato: ${result.rows[0].data_type}`);
    } else {
      console.log('⚠️ Advertencia: No se pudo verificar la creación de la columna');
    }

  } catch (error) {
    console.error('❌ Error al ejecutar migración:');
    console.error(error.message);
    
    if (error.message.includes('already exists')) {
      console.log('\n⚠️ Nota: La columna ya existe. Esto es normal si ejecutaste la migración antes.');
    } else {
      process.exit(1);
    }
  } finally {
    await client.end();
    console.log('\n🔌 Conexión cerrada');
  }
}

runMigration();
























