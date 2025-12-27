import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  UseGuards,
  Optional,
  BadRequestException,
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
import { RecordAdPlayDto } from './dto/record-ad-play.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../../common/entities/user.entity';
import { Logger } from '@nestjs/common';

@ApiTags('public-ads')
@Controller('public/ads')
export class PublicAdsController {
  private readonly logger = new Logger(PublicAdsController.name);

  constructor(private readonly adsService: AdsService) { }

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
  @UseGuards(OptionalJwtAuthGuard)
  @ApiResponse({ status: 200, description: 'Siguiente anuncio obtenido' })
  @ApiResponse({ status: 404, description: 'No hay anuncios disponibles' })
  async getNextAd(
    @CurrentUser() @Optional() user: User | undefined,
    @Query('genre') genre?: string,
    @Query('artist') artist?: string,
    @Query('playlistId') playlistId?: string,
  ) {
    console.log(`[BACKEND DEBUG] /public/ads/next HIT! User: ${user?.id}, Genre: ${genre}`);
    this.logger.log(`[getNextAd] 📢 Request recibido - usuario: ${user?.id || 'anónimo'} (Global Mode)`);

    try {
      // Ignoramos el resto de parámetros (genre, artist) en Global Mode
      const ad = await this.adsService.getNextAd(user?.id, {});

      if (!ad) {
        this.logger.warn(`[getNextAd] 📢 No se encontró anuncio para usuario: ${user?.id || 'anónimo'}`);
        return { ad: null };
      }

      this.logger.log(`[getNextAd] 📢 ✅ Anuncio encontrado: ${ad.title} (ID: ${ad.id})`);
      return { ad };
    } catch (error) {
      this.logger.error(`[getNextAd] ❌ Error interno al obtener anuncio: ${error.message}`, error.stack);
      // Return null ad instead of 500 error to keep music playing
      return { ad: null };
    }
  }

  @Post(':id/log-play')
  @ApiOperation({ summary: 'Registrar reproducción de anuncio' })
  @ApiParam({ name: 'id', description: 'ID del anuncio' })
  @ApiBearerAuth()
  @UseGuards(OptionalJwtAuthGuard)
  @ApiResponse({ status: 201, description: 'Reproducción registrada exitosamente' })
  async logPlay(
    @Param('id') id: string,
    @CurrentUser() @Optional() user: User | undefined,
    @Body() body: RecordAdPlayDto,
  ) {
    this.logger.log(`[logPlay] 📡 RECEIVING REQUEST for AdId: ${id}`);
    this.logger.log(`[logPlay] 📦 Body: ${JSON.stringify(body)}`);

    if (!id) {
      this.logger.warn('[logPlay] 🛑 Rejecting request with empty ID param');
      throw new BadRequestException('Ad ID is required');
    }

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
  @UseGuards(OptionalJwtAuthGuard)
  @ApiResponse({ status: 201, description: 'Click registrado exitosamente' })
  async logClick(
    @Param('id') id: string,
    @CurrentUser() @Optional() user: User | undefined,
  ) {
    return this.adsService.logClick(id, user?.id);
  }
}





