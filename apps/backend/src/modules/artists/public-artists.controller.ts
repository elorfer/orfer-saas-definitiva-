import {
  Controller,
  Get,
  Post,
  Delete,
  Query,
  Param,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery, ApiBearerAuth, ApiParam } from '@nestjs/swagger';

import { ArtistsService } from './artists.service';
import { FeaturedService } from '../featured/featured.service';
import { ArtistSerializer } from '../../common/utils/artist-serializer';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../../common/entities/user.entity';

@ApiTags('public-artists')
@Controller('public/artists')
export class PublicArtistsController {
  constructor(
    private readonly artistsService: ArtistsService,
    private readonly featuredService: FeaturedService,
  ) {}

  @Get('top')
  @ApiOperation({ summary: 'Obtener artistas más populares (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de artistas a devolver' })
  @ApiResponse({ status: 200, description: 'Lista de artistas top obtenida exitosamente' })
  async getTopArtists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    const artists = await this.artistsService.getTopArtists(limit);
    return artists.map((a) => ArtistSerializer.serializeLite(a));
  }

  @Get()
  @ApiOperation({ summary: 'Obtener todos los artistas (público)' })
  @ApiQuery({ name: 'page', required: false, type: Number, description: 'Número de página' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Elementos por página' })
  @ApiResponse({ status: 200, description: 'Lista de artistas obtenida exitosamente' })
  async findAll(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    const { artists, total } = await this.artistsService.findAll(page, limit);
    return { artists: artists.map((a) => ArtistSerializer.serializeLite(a)), total };
  }

  @Get('featured')
  @ApiOperation({ summary: 'Obtener artistas destacados (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de artistas a devolver' })
  @ApiResponse({ status: 200, description: 'Lista de artistas destacados' })
  async getFeatured(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 20,
  ) {
    // Usar FeaturedService para consistencia (mismo ordenamiento y validación)
    // Validar límite como en PublicFeaturedController
    const validLimit = Math.min(Math.max(1, limit), 100);
    const artists = await this.featuredService.getFeaturedArtists(validLimit);
    return artists.map((a) => ArtistSerializer.serializeLite(a));
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener detalle público de un artista' })
  @ApiResponse({ status: 200, description: 'Detalle del artista' })
  async getByIdPublic(@Param('id') id: string) {
    const artist = await this.artistsService.findOne(id);
    return ArtistSerializer.serializeFull(artist);
  }

  // ========== ENDPOINTS DE SEGUIMIENTO (requieren autenticación) ==========

  @Post(':artistId/follow')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Seguir un artista' })
  @ApiParam({ name: 'artistId', description: 'ID del artista a seguir' })
  @ApiResponse({ status: 200, description: 'Artista seguido exitosamente' })
  @ApiResponse({ status: 404, description: 'Artista no encontrado' })
  @ApiResponse({ status: 400, description: 'Ya estás siguiendo a este artista o no puedes seguirte a ti mismo' })
  async followArtist(
    @Param('artistId') artistId: string,
    @CurrentUser() user: User,
  ) {
    const result = await this.artistsService.followArtist(artistId, user.id);
    const artist = await this.artistsService.findOne(artistId);
    return {
      ...result,
      artist: ArtistSerializer.serializeLite(artist),
    };
  }

  @Delete(':artistId/follow')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Dejar de seguir un artista' })
  @ApiParam({ name: 'artistId', description: 'ID del artista a dejar de seguir' })
  @ApiResponse({ status: 200, description: 'Dejaste de seguir al artista exitosamente' })
  @ApiResponse({ status: 404, description: 'Artista no encontrado' })
  async unfollowArtist(
    @Param('artistId') artistId: string,
    @CurrentUser() user: User,
  ) {
    const result = await this.artistsService.unfollowArtist(artistId, user.id);
    const artist = await this.artistsService.findOne(artistId);
    return {
      ...result,
      artist: ArtistSerializer.serializeLite(artist),
    };
  }

  @Get(':artistId/is-followed')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Verificar si el usuario sigue a un artista' })
  @ApiParam({ name: 'artistId', description: 'ID del artista' })
  @ApiQuery({ name: 'userId', required: false, description: 'ID del usuario (opcional, usa el usuario autenticado por defecto)' })
  @ApiResponse({ status: 200, description: 'Estado de seguimiento' })
  @ApiResponse({ status: 404, description: 'Artista no encontrado' })
  async isFollowing(
    @Param('artistId') artistId: string,
    @CurrentUser() user: User,
    @Query('userId') userId?: string,
  ) {
    const targetUserId = userId || user.id;
    const isFollowing = await this.artistsService.isFollowing(artistId, targetUserId);
    return { isFollowing };
  }

  @Get('followed/mine')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Obtener lista de artistas seguidos por el usuario autenticado' })
  @ApiResponse({ status: 200, description: 'Lista de artistas seguidos' })
  async getMyFollowedArtists(@CurrentUser() user: User) {
    const artists = await this.artistsService.getFollowedArtists(user.id);
    return {
      artists: artists.map((artist) => ArtistSerializer.serializeLite(artist)),
      total: artists.length,
    };
  }
}

