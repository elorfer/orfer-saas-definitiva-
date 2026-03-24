import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SettingsService } from './settings.service';
import { Song, SongStatus } from '../../common/entities/song.entity';

@ApiTags('public-settings')
@Controller('public/ads')
export class PublicSettingsController {
  constructor(
    private readonly settingsService: SettingsService,
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
  ) { }

  /**
   * Endpoint público para obtener la frecuencia de anuncios.
   * La app Flutter consulta este endpoint para saber cada cuántas canciones mostrar un anuncio.
   * 
   * @returns Número de canciones entre anuncios (ej: 3)
   */
  @Get('frequency')
  @ApiOperation({
    summary: 'Obtener frecuencia de anuncios',
    description: 'Retorna el número de canciones que se reproducen entre cada anuncio. Por defecto es 3.',
  })
  @ApiResponse({
    status: 200,
    description: 'Frecuencia de anuncios obtenida exitosamente',
    schema: {
      type: 'object',
      properties: {
        frequency: {
          type: 'number',
          example: 3,
          description: 'Número de canciones entre anuncios',
        },
      },
    },
  })
  async getAdFrequency(): Promise<{ frequency: number }> {
    const frequency = await this.settingsService.getAdFrequency();
    return { frequency };
  }

  /**
   * Endpoint público para obtener la configuración del algoritmo de recomendaciones.
   * La app Flutter consulta este endpoint al iniciar para configurar dinámicamente el algoritmo.
   * 
   * @returns Objeto con todas las configuraciones del algoritmo
   */
  @Get('algorithm-config')
  @ApiOperation({
    summary: 'Obtener configuración del algoritmo',
    description: 'Retorna todas las configuraciones dinámicas del algoritmo de recomendaciones.',
  })
  @ApiResponse({
    status: 200,
    description: 'Configuración del algoritmo obtenida exitosamente',
    schema: {
      type: 'object',
      properties: {
        historySize: { type: 'number', example: 100, description: 'Historial de exclusión' },
        phase2Count: { type: 'number', example: 6, description: 'Canciones FASE 2.0' },
        phase31Count: { type: 'number', example: 20, description: 'Canciones FASE 3.1' },
        bufferSize: { type: 'number', example: 5, description: 'Buffer inicial FASE 1' },
        preloadThreshold: { type: 'number', example: 3, description: 'Umbral precarga' },
        criticalSongs: { type: 'number', example: 5, description: 'Canciones críticas' },
        catalogSize: { type: 'number', example: 0, description: 'Total canciones catálogo' },
        smallCatalogThreshold: { type: 'number', example: 150, description: 'Umbral catálogo pequeño' },
      },
    },
  })
  async getAlgorithmConfig(): Promise<{
    historySize: number;
    phase2Count: number;
    phase31Count: number;
    bufferSize: number;
    preloadThreshold: number;
    criticalSongs: number;
    catalogSize: number;
    smallCatalogThreshold: number;
    // ⚡ RENDIMIENTO Y UX
    controlDebounceMs: number;
    preloadCooldownMs: number;
    minQueueSize: number;
    cyclicBufferThreshold: number;
  }> {
    // 🎯 CONTEO DINÁMICO: Contar canciones publicadas en paralelo con otras configs
    const [
      historySize,
      phase2Count,
      phase31Count,
      bufferSize,
      preloadThreshold,
      criticalSongs,
      catalogSizeFromSettings,
      smallCatalogThreshold,
      publishedSongsCount,
      // ⚡ RENDIMIENTO Y UX
      controlDebounceMs,
      preloadCooldownMs,
      minQueueSize,
      cyclicBufferThreshold,
    ] = await Promise.all([
      this.settingsService.getValue('algorithm_history_size'),
      this.settingsService.getValue('algorithm_phase2_count'),
      this.settingsService.getValue('algorithm_phase31_count'),
      this.settingsService.getValue('algorithm_buffer_size'),
      this.settingsService.getValue('algorithm_preload_threshold'),
      this.settingsService.getValue('algorithm_critical_songs'),
      this.settingsService.getValue('catalog_size'),
      this.settingsService.getValue('catalog_small_threshold'),
      // ⚡ CONTEO REAL: Contar solo canciones publicadas (válidas para reproducción)
      this.songRepository.count({ where: { status: SongStatus.PUBLISHED } }),
      // ⚡ RENDIMIENTO Y UX
      this.settingsService.getValue('control_debounce_ms'),
      this.settingsService.getValue('preload_cooldown_ms'),
      this.settingsService.getValue('min_queue_size'),
      this.settingsService.getValue('cyclic_buffer_threshold'),
    ]);

    // Usar el conteo real si catalog_size no está configurado manualmente (es 0)
    const catalogSize = Number(catalogSizeFromSettings) > 0 ? Number(catalogSizeFromSettings) : publishedSongsCount;

    return {
      historySize: Number(historySize),
      phase2Count: Number(phase2Count),
      phase31Count: Number(phase31Count),
      bufferSize: Number(bufferSize),
      preloadThreshold: Number(preloadThreshold),
      criticalSongs: Number(criticalSongs),
      catalogSize,
      smallCatalogThreshold: Number(smallCatalogThreshold),
      // ⚡ RENDIMIENTO Y UX
      controlDebounceMs: Number(controlDebounceMs),
      preloadCooldownMs: Number(preloadCooldownMs),
      minQueueSize: Number(minQueueSize),
      cyclicBufferThreshold: Number(cyclicBufferThreshold),
    };
  }

  /**
   * Endpoint público para obtener los pesos del scoring del algoritmo.
   */
  @Get('scoring-weights')
  @ApiOperation({
    summary: 'Obtener pesos del scoring',
    description: 'Retorna los pesos configurados para el algoritmo de scoring de recomendaciones.',
  })
  @ApiResponse({
    status: 200,
    description: 'Pesos del scoring obtenidos exitosamente',
    schema: {
      type: 'object',
      properties: {
        genreWeight: { type: 'number', example: 30, description: 'Peso de similitud de género (0-100)' },
        popularityWeight: { type: 'number', example: 20, description: 'Peso de popularidad (0-100)' },
        artistWeight: { type: 'number', example: 10, description: 'Peso de mismo artista (0-100)' },
        noveltyWeight: { type: 'number', example: 20, description: 'Peso de novedad (0-100)' },
        affinityWeight: { type: 'number', example: 20, description: 'Peso de afinidad de usuario (0-100)' },
        total: { type: 'number', example: 100, description: 'Suma total de pesos (debe ser 100)' },
      },
    },
  })
  async getScoringWeights(): Promise<{
    genreWeight: number;
    popularityWeight: number;
    artistWeight: number;
    noveltyWeight: number;
    affinityWeight: number;
    total: number;
  }> {
    const [
      genreWeight,
      popularityWeight,
      artistWeight,
      noveltyWeight,
      affinityWeight,
    ] = await Promise.all([
      this.settingsService.getValue('weight_genre'),
      this.settingsService.getValue('weight_popularity'),
      this.settingsService.getValue('weight_artist'),
      this.settingsService.getValue('weight_novelty'),
      this.settingsService.getValue('weight_affinity'),
    ]);

    return {
      genreWeight: Number(genreWeight),
      popularityWeight: Number(popularityWeight),
      artistWeight: Number(artistWeight),
      noveltyWeight: Number(noveltyWeight),
      affinityWeight: Number(affinityWeight),
      total: Number(genreWeight) + Number(popularityWeight) + Number(artistWeight) + Number(noveltyWeight) + Number(affinityWeight),
    };
  }
}











