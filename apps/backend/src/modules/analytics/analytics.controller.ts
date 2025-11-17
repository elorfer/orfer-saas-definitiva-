import {
  Controller,
  Get,
  Param,
  UseGuards,
  Query,
  ParseIntPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';

import { AnalyticsService } from './analytics.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../../common/entities/user.entity';

@ApiTags('analytics')
@Controller('analytics')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get('global')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener estadísticas globales (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Estadísticas globales' })
  async getGlobalStats() {
    return this.analyticsService.getGlobalStats();
  }

  @Get('top-songs')
  @ApiOperation({ summary: 'Obtener canciones más populares' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de canciones top' })
  async getTopSongs(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.analyticsService.getTopSongs(limit);
  }

  @Get('top-artists')
  @ApiOperation({ summary: 'Obtener artistas más populares' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de artistas top' })
  async getTopArtists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.analyticsService.getTopArtists(limit);
  }

  @Get('artist/:id')
  @Roles(UserRole.ARTIST, UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener analytics de un artista' })
  @ApiResponse({ status: 200, description: 'Analytics del artista' })
  async getArtistAnalytics(@Param('id') artistId: string) {
    return this.analyticsService.getArtistAnalytics(artistId);
  }

  @Get('song/:id')
  @Roles(UserRole.ARTIST, UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener analytics de una canción' })
  @ApiResponse({ status: 200, description: 'Analytics de la canción' })
  async getSongAnalytics(@Param('id') songId: string) {
    return this.analyticsService.getSongAnalytics(songId);
  }
}









