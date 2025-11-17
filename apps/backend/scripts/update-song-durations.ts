/**
 * Script para actualizar las duraciones de las canciones existentes
 * 
 * Uso:
 *   npm run ts-node scripts/update-song-durations.ts
 * 
 * O desde la raíz del proyecto:
 *   cd apps/backend
 *   npx ts-node scripts/update-song-durations.ts
 */

import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { SongsService } from '../src/modules/songs/songs.service';

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const songsService = app.get(SongsService);

  console.log('🔄 Iniciando actualización de duraciones...\n');

  try {
    const result = await songsService.updateAllDurations();
    
    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('✅ ACTUALIZACIÓN COMPLETADA');
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`📊 Canciones actualizadas: ${result.updated}`);
    console.log(`❌ Canciones fallidas: ${result.failed}`);
    
    if (result.errors.length > 0) {
      console.log('\n⚠️ Errores encontrados:');
      result.errors.forEach((error, index) => {
        console.log(`   ${index + 1}. ${error}`);
      });
    }
    
    console.log('═══════════════════════════════════════════════════════════\n');
  } catch (error) {
    console.error('❌ Error al ejecutar la actualización:', error);
    process.exit(1);
  } finally {
    await app.close();
  }
}

bootstrap();


