import {
  Controller,
  Get,
  Query,
  Param,
  ParseIntPipe,
  ParseBoolPipe,
  DefaultValuePipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery, ApiParam } from '@nestjs/swagger';
import { SongsService } from './songs.service';
import { SongQueryDto } from './dto/song-query.dto';
import { PaginatedSongsResponseDto, HomeFeedResponseDto, SongResponseDto } from './dto/song-response.dto';

@ApiTags('public-songs')
@Controller('public/songs')
export class PublicSongsController {
  constructor(private readonly songsService: SongsService) {}

  /**
   * Obtiene todas las canciones publicadas (optimizado para Flutter)
   * Endpoint principal para la app móvil
   */
  @Get()
  @ApiOperation({ 
    summary: 'Obtener canciones publicadas (optimizado para Flutter)',
    description: 'Endpoint principal para la app móvil. Retorna canciones publicadas con filtros opcionales por featured, artista, género y búsqueda.'
  })
  @ApiQuery({ name: 'page', required: false, type: Number, description: 'Número de página (default: 1)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Elementos por página (default: 20, max: 100)' })
  @ApiQuery({ name: 'featured', required: false, type: Boolean, description: 'Filtrar solo destacadas' })
  @ApiQuery({ name: 'artistId', required: false, type: String, description: 'Filtrar por artista' })
  @ApiQuery({ name: 'genreId', required: false, type: String, description: 'Filtrar por género' })
  @ApiQuery({ name: 'search', required: false, type: String, description: 'Búsqueda por título o artista' })
  @ApiResponse({ 
    status: 200, 
    description: 'Lista de canciones obtenida exitosamente',
    type: PaginatedSongsResponseDto,
  })
  async findAll(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number = 1,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number = 20,
    @Query('featured', new DefaultValuePipe(undefined)) featured?: string,
    @Query('artistId') artistId?: string,
    @Query('genreId') genreId?: string,
    @Query('search') search?: string,
  ): Promise<PaginatedSongsResponseDto> {
    const featuredBool = featured !== undefined ? featured === 'true' : undefined;
    
    return this.songsService.getPublishedSongs(
      page,
      Math.min(limit, 100), // Máximo 100 elementos
      featuredBool,
      artistId,
      genreId,
      search,
    );
  }

  /**
   * Obtiene canciones destacadas
   */
  @Get('featured')
  @ApiOperation({ 
    summary: 'Obtener canciones destacadas',
    description: 'Retorna solo las canciones marcadas como destacadas (featured: true)'
  })
  @ApiQuery({ name: 'page', required: false, type: Number, description: 'Número de página (default: 1)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Elementos por página (default: 20)' })
  @ApiResponse({ 
    status: 200, 
    description: 'Lista de canciones destacadas',
    type: PaginatedSongsResponseDto,
  })
  async getFeatured(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number = 1,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number = 20,
  ): Promise<PaginatedSongsResponseDto> {
    return this.songsService.getFeaturedSongs(page, limit);
  }

  /**
   * Obtiene el feed del home con canciones destacadas y nuevas
   */
  @Get('home-feed')
  @ApiOperation({ 
    summary: 'Obtener feed del home',
    description: 'Retorna canciones destacadas primero, seguidas de canciones nuevas. Optimizado para la pantalla principal de la app.'
  })
  @ApiQuery({ name: 'featuredLimit', required: false, type: Number, description: 'Límite de canciones destacadas (default: 10)' })
  @ApiQuery({ name: 'newSongsLimit', required: false, type: Number, description: 'Límite de canciones nuevas (default: 20)' })
  @ApiResponse({ 
    status: 200, 
    description: 'Feed del home obtenido exitosamente',
    type: HomeFeedResponseDto,
  })
  async getHomeFeed(
    @Query('featuredLimit', new DefaultValuePipe(10), ParseIntPipe) featuredLimit: number = 10,
    @Query('newSongsLimit', new DefaultValuePipe(20), ParseIntPipe) newSongsLimit: number = 20,
  ): Promise<HomeFeedResponseDto> {
    return this.songsService.getHomeFeed(featuredLimit, newSongsLimit);
  }

  /**
   * Obtener canciones más populares (mantiene compatibilidad)
   * IMPORTANTE: Debe estar ANTES de @Get(':id') para que la ruta 'top' no sea interpretada como un ID
   */
  @Get('top')
  @ApiOperation({ summary: 'Obtener canciones más populares (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de canciones a devolver' })
  @ApiResponse({ status: 200, description: 'Lista de canciones top obtenida exitosamente' })
  async getTopSongs(
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number = 10,
  ) {
    return this.songsService.getTopSongs(limit);
  }

  /**
   * Obtiene una canción por ID (optimizado para Flutter)
   * IMPORTANTE: Debe estar DESPUÉS de las rutas específicas como 'top' y 'featured'
   */
  @Get(':id')
  @ApiOperation({ summary: 'Obtener canción por ID (optimizado para Flutter)' })
  @ApiParam({ name: 'id', description: 'ID único de la canción' })
  @ApiResponse({ 
    status: 200, 
    description: 'Canción obtenida exitosamente',
    type: SongResponseDto,
  })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async findOne(@Param('id') id: string): Promise<SongResponseDto> {
    return this.songsService.findOneOptimized(id);
  }
}