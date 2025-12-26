const { DataSource } = require('typeorm');
const fs = require('fs');

const dataSource = new DataSource({
  type: 'postgres',
  url: 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
});

async function run() {
  try {
    await dataSource.initialize();
    console.log('✅ Conectado a la base de datos');
    
    const sql = fs.readFileSync('src/database/migrations/add-audio-analysis-columns.sql', 'utf8');
    console.log('📄 Ejecutando migración...');
    
    // Ejecutar cada statement por separado
    const statements = sql.split(';').filter(s => s.trim().length > 0);
    for (const stmt of statements) {
      try {
        await dataSource.query(stmt);
        console.log('✓ Ejecutado:', stmt.substring(0, 60).replace(/\n/g, ' ') + '...');
      } catch (e) {
        console.log('⚠️ (ya existe o error menor):', e.message.substring(0, 100));
      }
    }
    
    console.log('✅ Migración completada');
    await dataSource.destroy();
  } catch (e) {
    console.error('❌ Error:', e.message);
    process.exit(1);
  }
}

run();
