import {
  Controller,
  Get,
  Query,
  Param,
  ParseIntPipe,
  ParseBoolPipe,
  DefaultValuePipe,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery, ApiParam } from '@nestjs/swagger';
import { SongsService } from './songs.service';
import { SongMapper } from './mappers/song.mapper';
import { RecommendationService } from '../recommendations/recommendation.service';
import { SongQueryDto } from './dto/song-query.dto';
import { PaginatedSongsResponseDto, HomeFeedResponseDto, SongResponseDto } from './dto/song-response.dto';

@ApiTags('public-songs')
@Controller('public/songs')
export class PublicSongsController {
  private readonly logger = new Logger(PublicSongsController.name);
  
  constructor(
    private readonly songsService: SongsService,
    private readonly recommendationService: RecommendationService,
  ) {}

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
    
    // Log para debugging
    this.logger.log(`📥 Request recibido - artistId: ${artistId || 'ninguno'}, page: ${page}, limit: ${limit}`);
    
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
   * 🚀 GENERAR PLAYLIST BATCH (NUEVO ENDPOINT OPTIMIZADO)
   * Reemplaza múltiples llamadas frontend por una sola llamada backend
   * El backend maneja internamente el batching y la variedad
   * IMPORTANTE: Debe estar ANTES de 'recommended/:songId' para que la ruta no sea interpretada como un ID
   */
  @Get('playlist/generate')
  @ApiOperation({
    summary: '🚀 Generar batch de recomendaciones (optimizado)',
    description: 'Genera múltiples recomendaciones en una sola llamada. El backend maneja internamente el batching y garantiza variedad. Reemplaza múltiples llamadas frontend con offset.',
  })
  @ApiQuery({ name: 'seed', required: true, type: String, description: 'ID de la canción semilla' })
  @ApiQuery({ name: 'count', required: false, type: Number, description: 'Número de recomendaciones (default: 4, max: 20)' })
  @ApiQuery({ name: 'userId', required: false, type: String, description: 'ID del usuario para personalización' })
  @ApiQuery({ name: 'genres', required: false, type: [String], description: 'Géneros de la canción semilla' })
  @ApiQuery({ name: 'excludeIds', required: false, type: String, description: 'IDs separados por coma para excluir' })
  @ApiResponse({ status: 200, description: 'Lista de canciones recomendadas generadas en batch' })
  @ApiResponse({ status: 400, description: 'Parámetros inválidos' })
  async generatePlaylistBatch(
    @Query('seed') seed: string,
    @Query('count', new DefaultValuePipe(4), ParseIntPipe) count: number = 4,
    @Query('userId') userId?: string,
    @Query('genres') genres?: string | string[],
    @Query('excludeIds') excludeIds?: string,
  ) {
    const startTime = Date.now();
    this.logger.log(`🚀 [BATCH API] Generando ${count} recomendaciones para semilla: ${seed}`);
    
    // Validar count
    const validCount = Math.min(Math.max(1, count), 20); // Entre 1 y 20
    
    // Convertir genres a array si viene como string
    const genresArray = genres 
      ? (Array.isArray(genres) ? genres : [genres])
      : undefined;
    
    // Parsear excludeIds
    const excludeIdsArray = excludeIds 
      ? excludeIds.split(',').map(id => id.trim()).filter(id => id.length > 0)
      : [];
    
    this.logger.log(`🚫 [BATCH API] ExcludeIds recibidos: ${excludeIdsArray.length} IDs - ${excludeIdsArray.slice(0, 5).map(id => id.substring(0, 8)).join(', ')}${excludeIdsArray.length > 5 ? '...' : ''}`);
    
    // Llamar al servicio de recomendaciones
    const recommendations = await this.recommendationService.generatePlaylistBatch(
      seed,
      validCount,
      userId,
      genresArray,
      excludeIdsArray
    );
    
    // ✅ NOTA: El Service ya valida correctamente usando effectiveExcludeIds (reducidos por exclusión adaptativa)
    // No necesitamos validar nuevamente aquí con excludeIds originales, ya que sería incorrecto para catálogos pequeños
    // El Service garantiza que las recomendaciones no estén en los effectiveExcludeIds que realmente se usaron
    
    // Convertir a DTOs
    const songsDto = recommendations.map(song => SongMapper.toDto(song));
    
    const processingTime = Date.now() - startTime;
    this.logger.log(`✅ [BATCH API] Completado en ${processingTime}ms: ${songsDto.length}/${validCount} recomendaciones válidas`);
    
    return {
      songs: songsDto,
      count: songsDto.length,
      requested: validCount,
      seed: seed,
      processingTime,
      algorithm: 'spotify-style-batch-v1',
    };
  }

  /**
   * 🎵 RECOMENDACIONES ESTILO SPOTIFY (PÚBLICO - sin autenticación)
   * Algoritmo avanzado con ML básico, scoring inteligente y múltiples estrategias
   * IMPORTANTE: Debe estar ANTES de @Get(':id') para que la ruta 'recommended' no sea interpretada como un ID
   */
  @Get('recommended/:songId')
  @ApiOperation({ 
    summary: '🎵 Recomendaciones estilo Spotify (público)',
    description: 'Sistema avanzado de recomendaciones que combina Content-Based Filtering, Collaborative Filtering, análisis de popularidad y scoring inteligente. Similar al algoritmo de Spotify.',
  })
  @ApiParam({ name: 'songId', description: 'ID de la canción actual' })
  @ApiQuery({ name: 'genres', required: false, type: [String], description: 'Géneros de la canción actual (opcional)' })
  @ApiQuery({ name: 'userId', required: false, type: String, description: 'ID del usuario para personalización (opcional)' })
  @ApiQuery({ name: 'offset', required: false, type: Number, description: 'Offset para variar cache (no afecta lógica de recomendación)' })
  @ApiResponse({ status: 200, description: 'Canción recomendada con algoritmo avanzado' })
  @ApiResponse({ status: 404, description: 'Canción actual no encontrada' })
  async getRecommendedSong(
    @Param('songId') songId: string,
    @Query('genres') genres?: string | string[],
    @Query('userId') userId?: string,
    @Query('offset', new ParseIntPipe({ optional: true })) offset?: number,
  ) {
    const startTime = Date.now();
    this.logger.log(`🎵 [SPOTIFY-STYLE] Recomendación solicitada para: ${songId}`);
    this.logger.log(`👤 [SPOTIFY-STYLE] Usuario: ${userId || 'anónimo'}`);
    this.logger.log(`🏷️ [SPOTIFY-STYLE] Géneros: ${genres ? (Array.isArray(genres) ? genres.join(', ') : genres) : 'auto-detectar'}`);
    
    // Convertir genres a array si viene como string
    const genresArray = genres 
      ? (Array.isArray(genres) ? genres : [genres])
      : undefined;
    
    // Usar el nuevo servicio de recomendaciones estilo Spotify
    // 🚨 OFFSET: Pasar el offset al servicio para variar el cache (no afecta la lógica)
    const recommended = await this.recommendationService.getRecommendedSong(
      songId, 
      userId, 
      genresArray,
      offset // 🚨 Pasar offset para romper cache en llamadas paralelas
    );
    
    if (!recommended) {
      this.logger.log(`❌ [SPOTIFY-STYLE] No hay recomendaciones disponibles`);
      return { 
        message: 'No hay canciones recomendadas disponibles', 
        song: null,
        algorithm: 'spotify-style-v1',
        processingTime: Date.now() - startTime
      };
    }
    
    // Usar el mapper para convertir a DTO
    const songDto = SongMapper.toDto(recommended);
    
    const processingTime = Date.now() - startTime;
    this.logger.log(`✅ [SPOTIFY-STYLE] Recomendación completada en ${processingTime}ms`);
    this.logger.log(`🎵 [SPOTIFY-STYLE] Recomendada: ${recommended.title}`);
    this.logger.log(`👤 [SPOTIFY-STYLE] Artista: ${recommended.artist?.stageName || 'Desconocido'}`);
    this.logger.log(`🏷️ [SPOTIFY-STYLE] Géneros: ${recommended.genres?.join(', ') || 'ninguno'}`);
    
    return { 
      song: songDto,
      algorithm: 'spotify-style-v1',
      processingTime,
      metadata: {
        recommendationEngine: 'Advanced ML-based hybrid system',
        strategies: ['content-based', 'collaborative-filtering', 'popularity-based', 'trending'],
        scoringFactors: ['genre-similarity', 'popularity', 'artist-match', 'novelty', 'user-affinity']
      }
    };
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