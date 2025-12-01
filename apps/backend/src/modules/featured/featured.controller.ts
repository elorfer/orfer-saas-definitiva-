import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
  Query,
  ParseIntPipe,
  BadRequestException,
  GoneException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';

import { FeaturedService } from './featured.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../../common/entities/user.entity';

@ApiTags('featured')
@Controller('featured')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class FeaturedController {
  constructor(private readonly featuredService: FeaturedService) {}

  @Get('songs')
  @ApiOperation({ summary: 'Obtener canciones destacadas' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de canciones a devolver (1-100)' })
  @ApiResponse({ status: 200, description: 'Lista de canciones destacadas' })
  @ApiResponse({ status: 400, description: 'Límite inválido' })
  async getFeaturedSongs(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    if (limit < 1 || limit > 100) {
      throw new BadRequestException('El límite debe estar entre 1 y 100');
    }
    return this.featuredService.getFeaturedSongs(limit);
  }

  @Get('artists')
  @ApiOperation({ summary: 'Obtener artistas destacados' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de artistas a devolver (1-100)' })
  @ApiResponse({ status: 200, description: 'Lista de artistas destacados' })
  @ApiResponse({ status: 400, description: 'Límite inválido' })
  async getFeaturedArtists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    if (limit < 1 || limit > 100) {
      throw new BadRequestException('El límite debe estar entre 1 y 100');
    }
    return this.featuredService.getFeaturedArtists(limit);
  }

  @Get('playlists')
  @ApiOperation({ summary: 'Obtener playlists destacadas' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de playlists a devolver (1-100)' })
  @ApiResponse({ status: 200, description: 'Lista de playlists destacadas' })
  @ApiResponse({ status: 400, description: 'Límite inválido' })
  async getFeaturedPlaylists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    if (limit < 1 || limit > 100) {
      throw new BadRequestException('El límite debe estar entre 1 y 100');
    }
    return this.featuredService.getFeaturedPlaylists(limit);
  }

  @Post('songs/:id/feature')
  @ApiOperation({ summary: 'Destacar una canción' })
  @ApiResponse({ status: 200, description: 'Canción destacada exitosamente' })
  @ApiResponse({ status: 400, description: 'Error de validación: la canción no tiene géneros asignados o no está publicada' })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async featureSong(@Param('id') id: string) {
    return this.featuredService.setSongFeatured(id, true);
  }

  @Delete('songs/:id/feature')
  @ApiOperation({ summary: 'Quitar destacado de una canción' })
  @ApiResponse({ status: 200, description: 'Canción ya no está destacada' })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async unfeatureSong(@Param('id') id: string) {
    return this.featuredService.setSongFeatured(id, false);
  }

  // Deshabilitado: gestión de destacados de artistas se hace desde módulo Artists
  @Post('artists/:id/feature')
  @ApiOperation({ summary: 'Deshabilitado: gestionar destacado desde /artists' })
  async featureArtist(@Param('id') id: string) {
    throw new GoneException('Este endpoint está deshabilitado. Usa /artists/:id/feature (toggle) en el módulo Artists.');
  }

  @Delete('artists/:id/feature')
  @ApiOperation({ summary: 'Deshabilitado: gestionar destacado desde /artists' })
  async unfeatureArtist(@Param('id') id: string) {
    throw new GoneException('Este endpoint está deshabilitado. Usa /artists/:id/feature (toggle) en el módulo Artists.');
  }

  @Post('playlists/:id/feature')
  @ApiOperation({ summary: 'Destacar una playlist' })
  @ApiResponse({ status: 200, description: 'Playlist destacada exitosamente' })
  @ApiResponse({ status: 404, description: 'Playlist no encontrada' })
  async featurePlaylist(@Param('id') id: string) {
    return this.featuredService.setPlaylistFeatured(id, true);
  }

  @Delete('playlists/:id/feature')
  @ApiOperation({ summary: 'Quitar destacado de una playlist' })
  @ApiResponse({ status: 200, description: 'Playlist ya no está destacada' })
  @ApiResponse({ status: 404, description: 'Playlist no encontrada' })
  async unfeaturePlaylist(@Param('id') id: string) {
    return this.featuredService.setPlaylistFeatured(id, false);
  }
}

