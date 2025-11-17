import {
  Controller,
  Get,
  Param,
  Query,
  ParseIntPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery, ApiParam } from '@nestjs/swagger';

import { PlaylistsService } from './playlists.service';

@ApiTags('public-playlists')
@Controller('public/playlists')
export class PublicPlaylistsController {
  constructor(private readonly playlistsService: PlaylistsService) {}

  @Get('featured')
  @ApiOperation({ summary: 'Obtener playlists destacadas (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Número de playlists a devolver' })
  @ApiResponse({ status: 200, description: 'Lista de playlists destacadas obtenida exitosamente' })
  async getFeaturedPlaylists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.playlistsService.getFeaturedPlaylists(limit);
  }

  @Get()
  @ApiOperation({ summary: 'Obtener todas las playlists públicas' })
  @ApiQuery({ name: 'page', required: false, type: Number, description: 'Número de página' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Elementos por página' })
  @ApiResponse({ status: 200, description: 'Lista de playlists públicas obtenida exitosamente' })
  async findAll(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.playlistsService.findAll(page, limit);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener playlist por ID (público)' })
  @ApiResponse({ status: 200, description: 'Playlist obtenida exitosamente' })
  @ApiResponse({ status: 404, description: 'Playlist no encontrada' })
  async findOne(
    @Param('id') id: string,
  ) {
    return this.playlistsService.findOne(id);
  }
}
