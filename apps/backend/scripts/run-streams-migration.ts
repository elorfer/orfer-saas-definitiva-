import { Client } from 'pg';
import { readFileSync } from 'fs';
import { join } from 'path';
import * as dotenv from 'dotenv';

dotenv.config();

async function runMigration() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL || 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  });

  try {
    console.log('🔌 Conectando a la base de datos...');
    await client.connect();
    console.log('✅ Conectado a PostgreSQL');

    console.log('📄 Leyendo archivo de migración...');
    const migrationPath = join(__dirname, '../src/database/migrations/create-streams-system.sql');
    const migrationSQL = readFileSync(migrationPath, 'utf-8');

    console.log('🚀 Ejecutando migración...');
    await client.query(migrationSQL);
    
    console.log('✅ Migración ejecutada exitosamente!');
    console.log('   - Tabla streams creada');
    console.log('   - Tabla user_listening_sessions creada');
    console.log('   - Índices creados');
    console.log('   - Triggers configurados');

    // Verificar que las tablas existen
    const tablesCheck = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name IN ('streams', 'user_listening_sessions')
    `);

    console.log('\n📊 Tablas verificadas:');
    tablesCheck.rows.forEach(row => {
      console.log(`   ✓ ${row.table_name}`);
    });

  } catch (error) {
    console.error('❌ Error ejecutando migración:', error);
    process.exit(1);
  } finally {
    await client.end();
  }
}

runMigration();






