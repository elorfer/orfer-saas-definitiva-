import {
  Controller,
  Get,
  Query,
  ParseIntPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery } from '@nestjs/swagger';

import { ArtistsService } from '../artists/artists.service';
import { SongsService } from '../songs/songs.service';
import { PlaylistsService } from '../playlists/playlists.service';

@ApiTags('public')
@Controller('public')
export class PublicController {
  constructor(
    private readonly artistsService: ArtistsService,
    private readonly songsService: SongsService,
    private readonly playlistsService: PlaylistsService,
  ) {}

  @Get('artists/top')
  @ApiOperation({ summary: 'Obtener artistas más populares (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de artistas top' })
  async getTopArtists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.artistsService.getTopArtists(limit);
  }

  @Get('songs/top')
  @ApiOperation({ summary: 'Obtener canciones más populares (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de canciones top' })
  async getTopSongs(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.songsService.getTopSongs(limit);
  }

  @Get('playlists/featured')
  @ApiOperation({ summary: 'Obtener playlists destacadas (público)' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de playlists destacadas' })
  async getFeaturedPlaylists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.playlistsService.getFeaturedPlaylists(limit);
  }
}



















