import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { SettingsService } from './settings.service';

@ApiTags('public-settings')
@Controller('public/ads')
export class PublicSettingsController {
  constructor(private readonly settingsService: SettingsService) {}

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
}











