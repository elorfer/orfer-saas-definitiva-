import {
  Controller,
  Get,
  Query,
  Param,
  ParseIntPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery } from '@nestjs/swagger';

import { ArtistsService } from './artists.service';

@ApiTags('public-artists')
@Controller('public/artists')
export class PublicArtistsController {
  constructor(private readonly artistsService: ArtistsService) {}

  private serializeArtistLite(artist: any) {
    const profilePhotoUrl = artist.profilePhotoUrl ?? artist.user?.avatarUrl ?? null;
    const coverPhotoUrl = artist.coverPhotoUrl ?? null;
    const name = artist.name ?? artist.stageName;
    
    return {
      id: artist.id,
      name,
      stageName: artist.stageName ?? name,
      // Ambas variantes para máxima compatibilidad (camelCase y snake_case)
      profilePhotoUrl,
      profile_photo_url: profilePhotoUrl,
      coverPhotoUrl,
      cover_photo_url: coverPhotoUrl,
      nationalityCode: artist.nationalityCode ?? null,
      nationality_code: artist.nationalityCode ?? null,
      featured: !!artist.featured,
      is_featured: !!artist.featured,
      totalStreams: artist.totalStreams ?? 0,
      total_streams: artist.totalStreams ?? 0,
      totalFollowers: artist.totalFollowers ?? 0,
      total_followers: artist.totalFollowers ?? 0,
      monthlyListeners: artist.monthlyListeners ?? 0,
      monthly_listeners: artist.monthlyListeners ?? 0,
    };
  }

  @Get('top')
  @ApiOperation({ summary: 'Obtener artistas más populares (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de artistas a devolver' })
  @ApiResponse({ status: 200, description: 'Lista de artistas top obtenida exitosamente' })
  async getTopArtists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    const artists = await this.artistsService.getTopArtists(limit);
    return artists.map((a) => this.serializeArtistLite(a));
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
    return { artists: artists.map((a) => this.serializeArtistLite(a)), total };
  }

  @Get('featured')
  @ApiOperation({ summary: 'Obtener artistas destacados (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de artistas a devolver' })
  @ApiResponse({ status: 200, description: 'Lista de artistas destacados' })
  async getFeatured(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 20,
  ) {
    const artists = await this.artistsService.findFeatured(limit);
    return artists.map((a) => this.serializeArtistLite(a));
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener detalle público de un artista' })
  @ApiResponse({ status: 200, description: 'Detalle del artista' })
  async getByIdPublic(@Param('id') id: string) {
    const artist = await this.artistsService.findOne(id);
    const biography = artist.biography ?? artist.bio ?? null;
    const profilePhotoUrl = artist.profilePhotoUrl ?? null;
    const coverPhotoUrl = artist.coverPhotoUrl ?? null;
    const nationalityCode = artist.nationalityCode ?? null;
    return {
      id: artist.id,
      name: artist.name ?? artist.stageName,
      stageName: artist.stageName,
      // Ambas variantes para máxima compatibilidad (camelCase y snake_case)
      biography,
      bio: biography,
      profilePhotoUrl,
      profile_photo_url: profilePhotoUrl,
      coverPhotoUrl,
      cover_photo_url: coverPhotoUrl,
      nationalityCode,
      nationality_code: nationalityCode,
      verificationStatus: artist.verificationStatus ?? false,
      totalStreams: artist.totalStreams ?? 0,
      totalFollowers: artist.totalFollowers ?? 0,
      monthlyListeners: artist.monthlyListeners ?? 0,
    };
  }
}

