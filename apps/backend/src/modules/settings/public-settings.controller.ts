import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { SettingsService } from './settings.service';

@ApiTags('public-settings')
@Controller('public/ads')
export class PublicSettingsController {
  constructor(private readonly settingsService: SettingsService) { }

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
  }> {
    const [
      historySize,
      phase2Count,
      phase31Count,
      bufferSize,
      preloadThreshold,
      criticalSongs,
      catalogSize,
      smallCatalogThreshold,
    ] = await Promise.all([
      this.settingsService.getValue('algorithm_history_size'),
      this.settingsService.getValue('algorithm_phase2_count'),
      this.settingsService.getValue('algorithm_phase31_count'),
      this.settingsService.getValue('algorithm_buffer_size'),
      this.settingsService.getValue('algorithm_preload_threshold'),
      this.settingsService.getValue('algorithm_critical_songs'),
      this.settingsService.getValue('catalog_size'),
      this.settingsService.getValue('catalog_small_threshold'),
    ]);

    return {
      historySize,
      phase2Count,
      phase31Count,
      bufferSize,
      preloadThreshold,
      criticalSongs,
      catalogSize,
      smallCatalogThreshold,
    };
  }
}











