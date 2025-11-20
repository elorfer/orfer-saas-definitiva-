import {
  Controller,
  Get,
  Query,
  Param,
  ParseIntPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery } from '@nestjs/swagger';

import { ArtistsService } from './artists.service';
import { FeaturedService } from '../featured/featured.service';
import { ArtistSerializer } from '@/common/utils/artist-serializer';

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
}

