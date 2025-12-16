import { DataSource } from 'typeorm';
import { config } from 'dotenv';
import { dataSourceOptions } from '../src/database/data-source';

config();

async function createIndexes() {
  const dataSource = new DataSource(dataSourceOptions);
  
  try {
    await dataSource.initialize();
    console.log('✅ Conectado a la base de datos');
    
    const queries = [
      `CREATE INDEX IF NOT EXISTS idx_songs_status_file_url ON songs(status, file_url) 
       WHERE file_url IS NOT NULL AND file_url != '';`,
      `CREATE INDEX IF NOT EXISTS idx_songs_status_streams ON songs(status, total_streams DESC) 
       WHERE status = 'published';`,
    ];
    
    for (const query of queries) {
      try {
        await dataSource.query(query);
        console.log(`✅ Índice creado exitosamente`);
      } catch (error) {
        if (error.message?.includes('already exists')) {
          console.log(`ℹ️  Índice ya existe, omitiendo...`);
        } else {
          console.error(`❌ Error creando índice:`, error.message);
        }
      }
    }
    
    console.log('✅ Todos los índices han sido creados/verificados');
    
  } catch (error) {
    console.error('❌ Error conectando a la base de datos:', error.message);
    process.exit(1);
  } finally {
    await dataSource.destroy();
  }
}

createIndexes();















