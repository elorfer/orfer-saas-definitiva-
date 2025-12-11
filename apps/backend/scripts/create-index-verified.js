const { Client } = require('pg');
require('dotenv').config();

async function createIndex() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL || 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
  });

  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos');

    // Crear índice
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_artists_is_verified 
      ON artists(is_verified) 
      WHERE is_verified = TRUE
    `);

    console.log('✅ Índice creado exitosamente');

    // Verificar
    const result = await client.query(`
      SELECT indexname FROM pg_indexes 
      WHERE tablename = 'artists' AND indexname = 'idx_artists_is_verified'
    `);

    if (result.rows.length > 0) {
      console.log('✅ Índice verificado:', result.rows[0]);
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

createIndex();











