import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  UseGuards,
  Optional,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
  ApiParam,
} from '@nestjs/swagger';

import { AdsService } from './ads.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../../common/entities/user.entity';
import { Logger } from '@nestjs/common';

@ApiTags('public-ads')
@Controller('public/ads')
export class PublicAdsController {
  private readonly logger = new Logger(PublicAdsController.name);

  constructor(private readonly adsService: AdsService) {}

  @Get('active')
  @ApiOperation({ summary: 'Obtener anuncios activos (público)' })
  @ApiResponse({ status: 200, description: 'Lista de anuncios activos' })
  async getActiveAds() {
    return this.adsService.findActive();
  }

  @Get('next')
  @ApiOperation({ summary: 'Obtener siguiente anuncio (con lógica de selección)' })
  @ApiQuery({ name: 'genre', required: false, type: String })
  @ApiQuery({ name: 'artist', required: false, type: String })
  @ApiQuery({ name: 'playlistId', required: false, type: String })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiResponse({ status: 200, description: 'Siguiente anuncio obtenido' })
  @ApiResponse({ status: 404, description: 'No hay anuncios disponibles' })
  async getNextAd(
    @CurrentUser() @Optional() user: User | undefined,
    @Query('genre') genre?: string,
    @Query('artist') artist?: string,
    @Query('playlistId') playlistId?: string,
  ) {
    this.logger.log(`[getNextAd] 📢 Request recibido - usuario: ${user?.id || 'anónimo'}, genre: ${genre || 'ninguno'}, artist: ${artist || 'ninguno'}, playlistId: ${playlistId || 'ninguno'}`);
    
    const ad = await this.adsService.getNextAd(user?.id, {
      genre,
      artist,
      playlistId,
    });

    if (!ad) {
      this.logger.warn(`[getNextAd] 📢 No se encontró anuncio para usuario: ${user?.id || 'anónimo'}`);
      return { ad: null };
    }

    this.logger.log(`[getNextAd] 📢 ✅ Anuncio encontrado: ${ad.title} (ID: ${ad.id})`);
    return { ad };
  }

  @Post(':id/log-play')
  @ApiOperation({ summary: 'Registrar reproducción de anuncio' })
  @ApiParam({ name: 'id', description: 'ID del anuncio' })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiResponse({ status: 201, description: 'Reproducción registrada exitosamente' })
  async logPlay(
    @Param('id') id: string,
    @CurrentUser() user: User | undefined,
    @Body() body: {
      durationPlayed: number;
      wasCompleted: boolean;
      wasSkipped: boolean;
      genre?: string;
      artist?: string;
      playlistId?: string;
    },
  ) {
    return this.adsService.logPlay(
      id,
      user?.id,
      body.durationPlayed,
      body.wasCompleted,
      body.wasSkipped,
      {
        genre: body.genre,
        artist: body.artist,
        playlistId: body.playlistId,
      },
    );
  }

  @Post(':id/log-click')
  @ApiOperation({ summary: 'Registrar click en anuncio' })
  @ApiParam({ name: 'id', description: 'ID del anuncio' })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiResponse({ status: 201, description: 'Click registrado exitosamente' })
  async logClick(
    @Param('id') id: string,
    @CurrentUser() user: User | undefined,
  ) {
    return this.adsService.logClick(id, user?.id);
  }
}





