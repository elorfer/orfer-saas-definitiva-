import {
  Controller,
  Get,
  Patch,
  Post,
  Put,
  Delete,
  Param,
  Body,
  UseGuards,
  Query,
  ParseIntPipe,
  UseInterceptors,
  UploadedFiles,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery, ApiConsumes, ApiParam, ApiBody } from '@nestjs/swagger';
import { FileFieldsInterceptor } from '@nestjs/platform-express';

import { ArtistsService } from './artists.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User, UserRole } from '../../common/entities/user.entity';

@ApiTags('artists')
@Controller('artists')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class ArtistsController {
  constructor(private readonly artistsService: ArtistsService) {}

  @Get()
  @ApiOperation({ summary: 'Obtener todos los artistas' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de artistas obtenida exitosamente' })
  async findAll(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.artistsService.findAll(page, limit);
  }

  @Get('featured')
  @ApiOperation({ summary: 'Obtener artistas destacados' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de artistas destacados' })
  async getFeatured(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 20,
  ) {
    return this.artistsService.findFeatured(limit);
  }

  @Get('top')
  @ApiOperation({ summary: 'Obtener artistas más populares' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de artistas top' })
  async getTopArtists(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.artistsService.getTopArtists(limit);
  }

  @Get('verified')
  @ApiOperation({ summary: 'Obtener artistas verificados' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de artistas verificados' })
  async getVerifiedArtists(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.artistsService.getVerifiedArtists(page, limit);
  }

  @Get('profile')
  @Roles(UserRole.ARTIST)
  @UseGuards(RolesGuard)
  @ApiOperation({ summary: 'Obtener perfil del artista autenticado' })
  @ApiResponse({ status: 200, description: 'Perfil del artista' })
  async getMyProfile(@CurrentUser() user: User) {
    return this.artistsService.findByUserId(user.id);
  }

  @Get('profile/stats')
  @Roles(UserRole.ARTIST)
  @UseGuards(RolesGuard)
  @ApiOperation({ summary: 'Obtener estadísticas del artista autenticado' })
  @ApiResponse({ status: 200, description: 'Estadísticas del artista' })
  async getMyStats(@CurrentUser() user: User) {
    const artist = await this.artistsService.findByUserId(user.id);
    return this.artistsService.getArtistStats(artist.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener artista por ID' })
  @ApiResponse({ status: 200, description: 'Artista encontrado' })
  @ApiResponse({ status: 404, description: 'Artista no encontrado' })
  async findOne(@Param('id') id: string) {
    return this.artistsService.findOne(id);
  }

  @Get(':id/stats')
  @ApiOperation({ summary: 'Obtener estadísticas de un artista' })
  @ApiResponse({ status: 200, description: 'Estadísticas del artista' })
  @ApiResponse({ status: 404, description: 'Artista no encontrado' })
  async getArtistStats(@Param('id') id: string) {
    return this.artistsService.getArtistStats(id);
  }

  @Post()
  @Roles(UserRole.ADMIN)
  @UseGuards(RolesGuard)
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'profile', maxCount: 1 },
        { name: 'cover', maxCount: 1 },
      ],
      {
        limits: {
          fileSize: 10 * 1024 * 1024, // 10MB por imagen
        },
        fileFilter: (req, file, cb) => {
          const allowed = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];
          if (allowed.includes(file.mimetype)) {
            cb(null, true);
          } else {
            cb(new Error('Tipo de archivo de imagen no permitido'), false);
          }
        },
      },
    ),
  )
  @ApiOperation({ summary: 'Crear artista (multipart/form-data)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        name: { type: 'string' },
        nationalityCode: { type: 'string', minLength: 2, maxLength: 2 },
        biography: { type: 'string' },
        featured: { type: 'boolean' },
        userId: { type: 'string' },
        profile: { type: 'string', format: 'binary' },
        cover: { type: 'string', format: 'binary' },
      },
      required: ['name'],
    },
  })
  @ApiResponse({ status: 201, description: 'Artista creado' })
  async createArtist(
    @UploadedFiles() files: { profile?: Express.Multer.File[]; cover?: Express.Multer.File[] },
    @Body() body: any,
  ) {
    const profileFile = files?.profile?.[0];
    const coverFile = files?.cover?.[0];
    return this.artistsService.createArtist({
      name: body?.name,
      nationalityCode: body?.nationalityCode,
      biography: body?.biography,
      featured: body?.featured === 'true' || body?.featured === true,
      userId: body?.userId,
      profileFile,
      coverFile,
    });
  }

  @Put(':id')
  @Roles(UserRole.ADMIN)
  @UseGuards(RolesGuard)
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'profile', maxCount: 1 },
        { name: 'cover', maxCount: 1 },
      ],
      {
        limits: {
          fileSize: 10 * 1024 * 1024,
        },
        fileFilter: (req, file, cb) => {
          const allowed = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];
          if (allowed.includes(file.mimetype)) {
            cb(null, true);
          } else {
            cb(new Error('Tipo de archivo de imagen no permitido'), false);
          }
        },
      },
    ),
  )
  @ApiOperation({ summary: 'Actualizar artista' })
  @ApiConsumes('multipart/form-data')
  @ApiResponse({ status: 200, description: 'Artista actualizado' })
  async updateArtist(
    @Param('id') id: string,
    @UploadedFiles() files: { profile?: Express.Multer.File[]; cover?: Express.Multer.File[] },
    @Body() body: any,
  ) {
    const profileFile = files?.profile?.[0];
    const coverFile = files?.cover?.[0];
    return this.artistsService.updateArtist(id, {
      name: body?.name,
      nationalityCode: body?.nationalityCode,
      biography: body?.biography,
      featured: body?.featured === 'true' || body?.featured === true,
      profileFile,
      coverFile,
    });
  }

  @Put(':id/feature')
  @Roles(UserRole.ADMIN)
  @UseGuards(RolesGuard)
  @ApiOperation({ summary: 'Marcar/desmarcar artista como destacado' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: { featured: { type: 'boolean' } },
      required: ['featured'],
    },
  })
  async featureArtist(
    @Param('id') id: string,
    @Body('featured') featured: boolean,
  ) {
    return this.artistsService.toggleFeatured(id, !!featured);
  }

  @Patch('profile')
  @Roles(UserRole.ARTIST)
  @UseGuards(RolesGuard)
  @ApiOperation({ summary: 'Actualizar perfil del artista autenticado' })
  @ApiResponse({ status: 200, description: 'Perfil actualizado exitosamente' })
  async updateMyProfile(
    @CurrentUser() user: User,
    @Body() updateData: any,
  ) {
    const artist = await this.artistsService.findByUserId(user.id);
    return this.artistsService.updateArtistProfile(artist.id, updateData);
  }

  @Patch(':id/verify')
  @Roles(UserRole.ADMIN)
  @UseGuards(RolesGuard)
  @ApiOperation({ summary: 'Verificar artista (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Artista verificado exitosamente' })
  @ApiResponse({ status: 404, description: 'Artista no encontrado' })
  async verifyArtist(@Param('id') id: string) {
    return this.artistsService.verifyArtist(id);
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  @UseGuards(RolesGuard)
  @ApiOperation({ summary: 'Eliminar artista (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Artista eliminado exitosamente' })
  @ApiResponse({ status: 404, description: 'Artista no encontrado' })
  async deleteArtist(@Param('id') id: string) {
    await this.artistsService.deleteArtist(id);
    return { message: 'Artista eliminado exitosamente' };
  }
}









