import {
  Controller,
  Get,
  Query,
  ParseIntPipe,
  BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery } from '@nestjs/swagger';

import { FeaturedService } from './featured.service';
import { ArtistSerializer } from '@/common/utils/artist-serializer';
import { PlaylistMapper } from '../playlists/mappers/playlist.mapper';
import { SongMapper } from '../songs/mappers/song.mapper';

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
    const songs = await this.featuredService.getFeaturedSongs(limit);
    // Usar SongMapper para asegurar que los géneros y otros campos se serialicen correctamente
    return {
      songs: SongMapper.toDtoArray(songs),
    };
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
    // Usar serializador compartido para evitar duplicación
    return artists.map((artist) => ArtistSerializer.serializeLite(artist));
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
    // Obtener las entidades con todas las relaciones cargadas y contadores actualizados
    const playlists = await this.featuredService.getFeaturedPlaylists(limit);
    // Mapear las entidades a DTOs para devolver en formato camelCase con todos los datos correctos
    return PlaylistMapper.toResponseDtoArray(playlists);
  }
}

