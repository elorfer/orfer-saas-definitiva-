import {
  Controller,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { StreamsService } from './streams.service';
import { TrackProgressDto } from './dto/track-progress.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../../common/entities/user.entity';

@ApiTags('streams')
@Controller('streams')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class StreamsController {
  constructor(private readonly streamsService: StreamsService) {}

  @Post('track-progress')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Registrar progreso de reproducción y validar stream' })
  @ApiResponse({
    status: 200,
    description: 'Progreso registrado. Retorna si debe registrar stream.',
    schema: {
      type: 'object',
      properties: {
        shouldRegisterStream: { type: 'boolean' },
        streamRegistered: { type: 'boolean' },
        message: { type: 'string' },
      },
    },
  })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  @ApiResponse({ status: 400, description: 'Datos inválidos' })
  async trackProgress(
    @CurrentUser() user: User,
    @Body() dto: TrackProgressDto,
  ) {
    return this.streamsService.trackProgress(user.id, dto);
  }

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Registrar stream (interno)',
    description: 'Endpoint interno para registrar stream después de validación',
  })
  @ApiResponse({ status: 201, description: 'Stream registrado exitosamente' })
  @ApiResponse({ status: 400, description: 'Rate limit alcanzado o datos inválidos' })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async registerStream(
    @CurrentUser() user: User,
    @Body() body: { songId: string },
  ) {
    return this.streamsService.registerStream(user.id, body.songId);
  }
}






