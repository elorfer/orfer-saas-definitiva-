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
    const sqlPath = path.join(__dirname, '../migrations/add_is_verified_to_artists.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('📄 Ejecutando migración...');
    await client.query(sql);

    console.log('✅ Migración ejecutada exitosamente');

    // Verificar que la columna existe
    const checkResult = await client.query(`
      SELECT column_name, data_type, column_default 
      FROM information_schema.columns 
      WHERE table_name = 'artists' AND column_name = 'is_verified'
    `);

    if (checkResult.rows.length > 0) {
      console.log('✅ Columna is_verified verificada:', checkResult.rows[0]);
    } else {
      console.log('⚠️  La columna is_verified no se encontró');
    }

    // Verificar índice
    const indexResult = await client.query(`
      SELECT indexname FROM pg_indexes 
      WHERE tablename = 'artists' AND indexname = 'idx_artists_is_verified'
    `);

    if (indexResult.rows.length > 0) {
      console.log('✅ Índice idx_artists_is_verified verificado');
    } else {
      console.log('⚠️  El índice no se encontró');
    }

    // Contar artistas verificados
    const countResult = await client.query(`
      SELECT COUNT(*) as total FROM artists WHERE is_verified = TRUE
    `);
    console.log(`📊 Artistas verificados: ${countResult.rows[0].total}`);

  } catch (error) {
    console.error('❌ Error ejecutando migración:', error.message);
    process.exit(1);
  } finally {
    await client.end();
    console.log('✅ Conexión cerrada');
  }
}

runMigration();



















