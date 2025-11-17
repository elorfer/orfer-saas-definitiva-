import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
  Query,
  ParseIntPipe,
  UseInterceptors,
  UploadedFile,
  ParseFilePipe,
  MaxFileSizeValidator,
  FileTypeValidator,
  ForbiddenException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery, ApiConsumes, ApiBody } from '@nestjs/swagger';

import { PlaylistsService } from './playlists.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../../common/entities/user.entity';
import { CreatePlaylistDto } from './dto/create-playlist.dto';
import { UpdatePlaylistDto } from './dto/update-playlist.dto';
import { CoversStorageService } from '../covers/covers-storage.service';

@ApiTags('playlists')
@Controller('playlists')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class PlaylistsController {
  constructor(
    private readonly playlistsService: PlaylistsService,
    private readonly coversStorageService: CoversStorageService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Obtener todas las playlists (Admin)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de playlists obtenida exitosamente' })
  async findAll(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.playlistsService.findAllForAdmin(page, limit);
  }

  @Get('featured')
  @ApiOperation({ summary: 'Obtener playlists destacadas' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de playlists destacadas' })
  async getFeaturedPlaylists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.playlistsService.getFeaturedPlaylists(limit);
  }

  @Get('my-playlists')
  @ApiOperation({ summary: 'Obtener mis playlists' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Mis playlists' })
  async getMyPlaylists(
    @CurrentUser() user: User,
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.playlistsService.findByUser(user.id, page, limit);
  }

  @Get('user/:userId')
  @ApiOperation({ summary: 'Obtener playlists de un usuario' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Playlists del usuario' })
  async findByUser(
    @Param('userId') userId: string,
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.playlistsService.findByUser(userId, page, limit);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener playlist por ID (admin - todas las playlists)' })
  @ApiResponse({ status: 200, description: 'Playlist encontrada' })
  @ApiResponse({ status: 404, description: 'Playlist no encontrada' })
  async findOne(@Param('id') id: string) {
    // El admin puede ver todas las playlists, no solo públicas
    return this.playlistsService.findOneForAdmin(id);
  }

  @Post()
  @ApiOperation({ summary: 'Crear nueva playlist' })
  @ApiResponse({ status: 201, description: 'Playlist creada exitosamente' })
  async createPlaylist(
    @Body() playlistData: CreatePlaylistDto,
    @CurrentUser() user: User,
  ) {
    return this.playlistsService.createPlaylist(user.id, playlistData);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Actualizar playlist completa' })
  @ApiResponse({ status: 200, description: 'Playlist actualizada exitosamente' })
  @ApiResponse({ status: 403, description: 'No tienes permisos para editar esta playlist' })
  async updatePlaylist(
    @Param('id') id: string,
    @Body() updateData: UpdatePlaylistDto,
    @CurrentUser() user: User,
  ) {
    return this.playlistsService.updatePlaylist(id, user.id, updateData);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Actualizar playlist parcialmente' })
  @ApiResponse({ status: 200, description: 'Playlist actualizada exitosamente' })
  @ApiResponse({ status: 403, description: 'No tienes permisos para editar esta playlist' })
  async patchPlaylist(
    @Param('id') id: string,
    @Body() updateData: UpdatePlaylistDto,
    @CurrentUser() user: User,
  ) {
    return this.playlistsService.updatePlaylist(id, user.id, updateData);
  }

  @Patch(':id/feature')
  @ApiOperation({ summary: 'Toggle destacar playlist' })
  @ApiResponse({ status: 200, description: 'Estado de destacada actualizado' })
  async toggleFeatured(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    return this.playlistsService.toggleFeatured(id, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Eliminar playlist' })
  @ApiResponse({ status: 200, description: 'Playlist eliminada exitosamente' })
  @ApiResponse({ status: 403, description: 'No tienes permisos para eliminar esta playlist' })
  async deletePlaylist(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    await this.playlistsService.deletePlaylist(id, user.id);
    return { message: 'Playlist eliminada exitosamente' };
  }

  @Post(':id/cover')
  @UseInterceptors(FileInterceptor('cover'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Subir portada de playlist' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        cover: {
          type: 'string',
          format: 'binary',
        },
      },
    },
  })
  @ApiResponse({ status: 200, description: 'Portada subida exitosamente' })
  async uploadCover(
    @Param('id') id: string,
    @CurrentUser() user: User,
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: 10 * 1024 * 1024 }), // 10MB
          new FileTypeValidator({ fileType: /^image\/(jpeg|jpg|png|webp)$/ }),
        ],
      }),
    )
    file: Express.Multer.File,
  ) {
    // Obtener la playlist como entidad para verificar permisos
    const playlist = await this.playlistsService.findOneEntity(id);

    if (playlist.userId !== user.id) {
      throw new ForbiddenException('No tienes permisos para editar esta playlist');
    }

    // Subir la portada
    const { url } = await this.coversStorageService.uploadCoverImage(file, user.id);

    // Actualizar la playlist con la nueva URL de la portada
    return this.playlistsService.updatePlaylist(id, user.id, { coverArtUrl: url });
  }

  @Post(':id/songs/:songId')
  @ApiOperation({ summary: 'Agregar canción a playlist' })
  @ApiResponse({ status: 200, description: 'Canción agregada exitosamente' })
  async addSongToPlaylist(
    @Param('id') playlistId: string,
    @Param('songId') songId: string,
    @CurrentUser() user: User,
  ) {
    await this.playlistsService.addSongToPlaylist(playlistId, songId, user.id);
    return { message: 'Canción agregada exitosamente' };
  }

  @Delete(':id/songs/:songId')
  @ApiOperation({ summary: 'Remover canción de playlist' })
  @ApiResponse({ status: 200, description: 'Canción removida exitosamente' })
  async removeSongFromPlaylist(
    @Param('id') playlistId: string,
    @Param('songId') songId: string,
    @CurrentUser() user: User,
  ) {
    await this.playlistsService.removeSongFromPlaylist(playlistId, songId, user.id);
    return { message: 'Canción removida exitosamente' };
  }
}
