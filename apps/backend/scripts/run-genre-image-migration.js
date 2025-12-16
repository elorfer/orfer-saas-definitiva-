const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function runMigration() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL || 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
  });

  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos');

    // Leer el archivo SQL
    const sqlPath = path.join(__dirname, '../src/database/migrations/add-image-url-to-genres.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('📄 Ejecutando migración: add-image-url-to-genres.sql');
    await client.query(sql);

    console.log('✅ Migración ejecutada exitosamente');

    // Verificar que la columna existe
    const checkResult = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'genres' AND column_name = 'image_url'
    `);

    if (checkResult.rows.length > 0) {
      console.log('✅ Columna image_url verificada:', checkResult.rows[0]);
    } else {
      console.log('⚠️  La columna image_url no se encontró');
    }

    // Contar géneros con imagen
    const countResult = await client.query(`
      SELECT COUNT(*) as total FROM genres WHERE image_url IS NOT NULL AND image_url != ''
    `);
    console.log(`📊 Géneros con imagen: ${countResult.rows[0].total}`);

  } catch (error) {
    console.error('❌ Error ejecutando migración:', error.message);
    if (error.code === '42710') {
      console.log('ℹ️  La columna ya existe, esto es normal si la migración ya se ejecutó antes');
    } else {
      process.exit(1);
    }
  } finally {
    await client.end();
    console.log('✅ Conexión cerrada');
  }
}

runMigration();













