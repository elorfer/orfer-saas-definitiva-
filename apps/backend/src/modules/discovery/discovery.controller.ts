import { Controller, Get, Query, Logger } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery, ApiResponse } from '@nestjs/swagger';
import { DiscoveryService } from './discovery.service';

@ApiTags('Discovery')
@Controller('discovery')
export class DiscoveryController {
  private readonly logger = new Logger(DiscoveryController.name);

  constructor(private readonly discoveryService: DiscoveryService) {}

  /**
   * 🎯 ENDPOINT SIMPLE: Siguiente canción para autoplay
   * 
   * Lógica simple basada en género:
   * 1. Busca canciones del mismo género
   * 2. Ordena por fecha de subida (más nuevas primero) o reproducciones
   * 3. Excluye la canción actual
   * 4. Si no hay del mismo género, elige una al azar
   */
  @Get('next-up')
  @ApiOperation({ 
    summary: 'Obtener siguiente canción para autoplay',
    description: 'Retorna canciones del mismo género, ordenadas por novedad o popularidad'
  })
  @ApiQuery({ name: 'genreId', required: false, description: 'ID del género de la canción actual' })
  @ApiQuery({ name: 'genres', required: false, description: 'Nombres de géneros (separados por coma)' })
  @ApiQuery({ name: 'currentSongId', required: true, description: 'ID de la canción actual (para excluir)' })
  @ApiQuery({ name: 'count', required: false, description: 'Número de canciones (default: 5)' })
  @ApiQuery({ name: 'excludeIds', required: false, description: 'IDs adicionales a excluir (separados por coma)' })
  @ApiResponse({ status: 200, description: 'Lista de canciones recomendadas' })
  async nextUp(
    @Query('genreId') genreId?: string,
    @Query('genres') genres?: string,
    @Query('currentSongId') currentSongId?: string,
    @Query('count') count?: string,
    @Query('excludeIds') excludeIds?: string,
  ) {
    const songCount = Math.min(Math.max(parseInt(count || '5', 10), 1), 20);
    const genreNames = genres ? genres.split(',').map(g => g.trim()).filter(Boolean) : [];
    const excluded = excludeIds ? excludeIds.split(',').filter(Boolean) : [];
    
    if (currentSongId) {
      excluded.push(currentSongId);
    }

    this.logger.log(`🔮 [DISCOVERY] next-up: genreId=${genreId}, genres=${genreNames.join(',')}, exclude=${excluded.length}`);

    const startTime = Date.now();
    const songs = await this.discoveryService.getNextUp(genreId, genreNames, excluded, songCount);
    const elapsed = Date.now() - startTime;

    this.logger.log(`✅ [DISCOVERY] Completado en ${elapsed}ms: ${songs.length} canciones`);
    
    return {
      songs,
      metadata: {
        genreId,
        genres: genreNames,
        count: songs.length,
        processingTimeMs: elapsed,
      },
    };
  }
}
