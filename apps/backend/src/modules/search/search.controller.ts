import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { SearchService } from './search.service';

@ApiTags('search')
@Controller('search')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get()
  @ApiOperation({ 
    summary: 'Búsqueda global unificada',
    description: 'Busca artistas, canciones y playlists en un solo endpoint. Retorna resultados de los tres tipos en paralelo.'
  })
  @ApiQuery({ name: 'q', required: true, type: String, description: 'Texto de búsqueda' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Límite de resultados por tipo (default: 10)' })
  @ApiResponse({ 
    status: 200, 
    description: 'Resultados de búsqueda obtenidos exitosamente',
    schema: {
      type: 'object',
      properties: {
        artists: { type: 'array' },
        songs: { type: 'array' },
        playlists: { type: 'array' },
        totals: {
          type: 'object',
          properties: {
            artists: { type: 'number' },
            songs: { type: 'number' },
            playlists: { type: 'number' },
          },
        },
      },
    },
  })
  async search(
    @Query('q') query: string,
    @Query('limit') limit?: number,
  ) {
    if (!query || query.trim().length === 0) {
      return {
        artists: [],
        songs: [],
        playlists: [],
        totals: {
          artists: 0,
          songs: 0,
          playlists: 0,
        },
      };
    }

    const searchLimit = limit ? Math.min(Math.max(1, limit), 50) : 10;
    return this.searchService.searchAll(query.trim(), searchLimit);
  }
}

