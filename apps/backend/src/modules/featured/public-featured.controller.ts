import {
  Controller,
  Get,
  Query,
  ParseIntPipe,
  BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery } from '@nestjs/swagger';

import { FeaturedService } from './featured.service';

@ApiTags('public-featured')
@Controller('public/featured')
export class PublicFeaturedController {
  constructor(private readonly featuredService: FeaturedService) {}

  @Get('songs')
  @ApiOperation({ summary: 'Obtener canciones destacadas (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de canciones a devolver (1-100)' })
  @ApiResponse({ status: 200, description: 'Lista de canciones destacadas obtenida exitosamente' })
  @ApiResponse({ status: 400, description: 'Límite inválido' })
  async getFeaturedSongs(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    // Validar límite en el controlador también
    if (limit < 1 || limit > 100) {
      throw new BadRequestException('El límite debe estar entre 1 y 100');
    }
    return this.featuredService.getFeaturedSongs(limit);
  }

  @Get('artists')
  @ApiOperation({ summary: 'Obtener artistas destacados (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de artistas a devolver (1-100)' })
  @ApiResponse({ status: 200, description: 'Lista de artistas destacados obtenida exitosamente' })
  @ApiResponse({ status: 400, description: 'Límite inválido' })
  async getFeaturedArtists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    // Validar límite en el controlador también
    if (limit < 1 || limit > 100) {
      throw new BadRequestException('El límite debe estar entre 1 y 100');
    }
    const artists = await this.featuredService.getFeaturedArtists(limit);
    // Serializar artistas con URLs normalizadas y ambos formatos (camelCase y snake_case)
    return artists.map((artist) => {
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
        featured: !!artist.isFeatured,
        is_featured: !!artist.isFeatured,
        totalStreams: artist.totalStreams ?? 0,
        total_streams: artist.totalStreams ?? 0,
        totalFollowers: artist.totalFollowers ?? 0,
        total_followers: artist.totalFollowers ?? 0,
        monthlyListeners: artist.monthlyListeners ?? 0,
        monthly_listeners: artist.monthlyListeners ?? 0,
      };
    });
  }

  @Get('playlists')
  @ApiOperation({ summary: 'Obtener playlists destacadas (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de playlists a devolver (1-100)' })
  @ApiResponse({ status: 200, description: 'Lista de playlists destacadas obtenida exitosamente' })
  @ApiResponse({ status: 400, description: 'Límite inválido' })
  async getFeaturedPlaylists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    // Validar límite en el controlador también
    if (limit < 1 || limit > 100) {
      throw new BadRequestException('El límite debe estar entre 1 y 100');
    }
    return this.featuredService.getFeaturedPlaylists(limit);
  }
}

