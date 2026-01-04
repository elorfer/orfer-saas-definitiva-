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
  constructor(private readonly analyticsService: AnalyticsService) { }

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

  @Get('daily-streams')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener reproducciones diarias de los últimos N días (Solo Admin)' })
  @ApiQuery({ name: 'days', required: false, type: Number, description: 'Número de días (default: 7)' })
  @ApiResponse({ status: 200, description: 'Reproducciones diarias' })
  async getDailyStreams(
    @Query('days', new ParseIntPipe({ optional: true })) days: number = 7,
  ) {
    return this.analyticsService.getDailyStreams(days);
  }

  @Get('daily-active-users')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener usuarios activos diarios de los últimos N días (Solo Admin)' })
  @ApiQuery({ name: 'days', required: false, type: Number, description: 'Número de días (default: 7)' })
  @ApiResponse({ status: 200, description: 'Usuarios activos diarios' })
  async getDailyActiveUsers(
    @Query('days', new ParseIntPipe({ optional: true })) days: number = 7,
  ) {
    return this.analyticsService.getDailyActiveUsers(days);
  }

  @Get('genre-distribution')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener distribución de reproducciones por género (Solo Admin)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Límite de géneros (default: 5)' })
  @ApiResponse({ status: 200, description: 'Distribución por géneros' })
  async getGenreDistribution(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 5,
  ) {
    return this.analyticsService.getGenreDistribution(limit);
  }

  @Get('peak-hours')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener horas pico de actividad (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Horas pico de actividad' })
  async getPeakHours() {
    return this.analyticsService.getPeakHours();
  }
}









