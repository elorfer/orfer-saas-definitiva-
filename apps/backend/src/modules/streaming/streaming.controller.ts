import {
  Controller,
  Get,
  Param,
  UseGuards,
  Query,
  ParseIntPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';

import { StreamingService } from './streaming.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../../common/entities/user.entity';

@ApiTags('streaming')
@Controller('streaming')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class StreamingController {
  constructor(private readonly streamingService: StreamingService) {}

  @Get('song/:id/stream')
  @ApiOperation({ summary: 'Obtener URL de streaming de una canción' })
  @ApiResponse({ status: 200, description: 'URL de streaming obtenida' })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async getStreamUrl(
    @Param('id') songId: string,
    @CurrentUser() user: User,
  ) {
    return this.streamingService.getStreamUrl(songId, user.id);
  }

  @Get('history')
  @ApiOperation({ summary: 'Obtener historial de reproducción del usuario' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Historial de reproducción' })
  async getPlayHistory(
    @CurrentUser() user: User,
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.streamingService.getUserPlayHistory(user.id, page, limit);
  }

  @Get('recently-played')
  @ApiOperation({ summary: 'Obtener canciones reproducidas recientemente' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Canciones reproducidas recientemente' })
  async getRecentlyPlayed(
    @CurrentUser() user: User,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.streamingService.getRecentlyPlayed(user.id, limit);
  }
}









