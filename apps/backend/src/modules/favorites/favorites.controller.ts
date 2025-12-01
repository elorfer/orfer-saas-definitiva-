import {
  Controller,
  Get,
  Post,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam } from '@nestjs/swagger';

import { FavoritesService } from './favorites.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../../common/entities/user.entity';

@ApiTags('favorites')
@Controller('favorites')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class FavoritesController {
  constructor(private readonly favoritesService: FavoritesService) {}

  @Post('toggle/:songId')
  @ApiOperation({ summary: 'Toggle de favorito: agregar o remover canción de favoritos' })
  @ApiParam({ name: 'songId', description: 'ID de la canción' })
  @ApiResponse({ 
    status: 200, 
    description: 'Favorito actualizado exitosamente',
    schema: {
      type: 'object',
      properties: {
        isFavorite: { type: 'boolean', description: 'true si se agregó, false si se removió' },
      },
    },
  })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async toggleFavorite(
    @CurrentUser() user: User,
    @Param('songId') songId: string,
  ) {
    return await this.favoritesService.toggleFavorite(user.id, songId);
  }

  @Get('my')
  @ApiOperation({ summary: 'Obtener todas las canciones favoritas del usuario actual' })
  @ApiResponse({ 
    status: 200, 
    description: 'Lista de canciones favoritas',
    schema: {
      type: 'object',
      properties: {
        songs: {
          type: 'array',
          items: { type: 'object' },
        },
      },
    },
  })
  async getMyFavorites(@CurrentUser() user: User) {
    return await this.favoritesService.getMyFavorites(user.id);
  }
}









