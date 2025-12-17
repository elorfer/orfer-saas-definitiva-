import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  ParseIntPipe,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
  ApiParam,
  ApiConsumes,
  ApiBody,
} from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';

import { AdsService } from './ads.service';
import { CreateAdDto } from './dto/create-ad.dto';
import { UpdateAdDto } from './dto/update-ad.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User, UserRole } from '../../common/entities/user.entity';
import { AdStatus } from '../../common/entities/audio-ad.entity';
import { IAdsStorageService } from './ads-storage.service';
import { Inject } from '@nestjs/common';

@ApiTags('ads')
@Controller('ads')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class AdsController {
  constructor(
    private readonly adsService: AdsService,
    @Inject('IAdsStorageService')
    private readonly adsStorageService: IAdsStorageService,
  ) {}

  @Post()
  @ApiOperation({ summary: 'Crear un nuevo anuncio' })
  @ApiResponse({ status: 201, description: 'Anuncio creado exitosamente' })
  @ApiResponse({ status: 400, description: 'Datos inválidos' })
  async create(@Body() createAdDto: CreateAdDto) {
    return this.adsService.create(createAdDto);
  }

  @Get()
  @ApiOperation({ summary: 'Obtener todos los anuncios' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'status', required: false, enum: AdStatus })
  @ApiResponse({ status: 200, description: 'Lista de anuncios obtenida exitosamente' })
  async findAll(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
    @Query('status') status?: AdStatus,
  ) {
    return this.adsService.findAll(page, limit, status);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener un anuncio por ID' })
  @ApiParam({ name: 'id', description: 'ID del anuncio' })
  @ApiResponse({ status: 200, description: 'Anuncio obtenido exitosamente' })
  @ApiResponse({ status: 404, description: 'Anuncio no encontrado' })
  async findOne(@Param('id') id: string) {
    return this.adsService.findOne(id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Actualizar un anuncio' })
  @ApiParam({ name: 'id', description: 'ID del anuncio' })
  @ApiResponse({ status: 200, description: 'Anuncio actualizado exitosamente' })
  @ApiResponse({ status: 404, description: 'Anuncio no encontrado' })
  async update(@Param('id') id: string, @Body() updateAdDto: UpdateAdDto) {
    return this.adsService.update(id, updateAdDto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Eliminar un anuncio' })
  @ApiParam({ name: 'id', description: 'ID del anuncio' })
  @ApiResponse({ status: 200, description: 'Anuncio eliminado exitosamente' })
  @ApiResponse({ status: 404, description: 'Anuncio no encontrado' })
  async remove(@Param('id') id: string) {
    await this.adsService.remove(id);
    return { message: 'Anuncio eliminado exitosamente' };
  }

  @Post(':id/activate')
  @ApiOperation({ summary: 'Activar un anuncio' })
  @ApiParam({ name: 'id', description: 'ID del anuncio' })
  @ApiResponse({ status: 200, description: 'Anuncio activado exitosamente' })
  async activate(@Param('id') id: string) {
    return this.adsService.activate(id);
  }

  @Post(':id/pause')
  @ApiOperation({ summary: 'Pausar un anuncio' })
  @ApiParam({ name: 'id', description: 'ID del anuncio' })
  @ApiResponse({ status: 200, description: 'Anuncio pausado exitosamente' })
  async pause(@Param('id') id: string) {
    return this.adsService.pause(id);
  }

  @Post(':id/upload-audio')
  @ApiOperation({ summary: 'Subir archivo de audio para un anuncio' })
  @ApiParam({ name: 'id', description: 'ID del anuncio' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
      },
    },
  })
  @UseInterceptors(FileInterceptor('file'))
  @ApiResponse({ status: 200, description: 'Audio subido exitosamente' })
  async uploadAudio(
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: User,
  ) {
    if (!file) {
      throw new BadRequestException('Archivo de audio requerido');
    }

    // Validar tipo de archivo
    const allowedMimeTypes = ['audio/mpeg', 'audio/mp3', 'audio/aac', 'audio/ogg'];
    if (!allowedMimeTypes.includes(file.mimetype)) {
      throw new BadRequestException('Tipo de archivo no permitido. Use MP3, AAC u OGG');
    }

    // Validar tamaño (máx 5MB)
    const maxSize = 5 * 1024 * 1024; // 5MB
    if (file.size > maxSize) {
      throw new BadRequestException('El archivo es demasiado grande. Máximo 5MB');
    }

    // Subir archivo usando el servicio de almacenamiento
    const uploadResult = await this.adsStorageService.uploadAudioFile(file, id);

    // Actualizar anuncio con la URL del audio y duración
    return this.adsService.update(id, {
      audioUrl: uploadResult.url,
      fileSizeBytes: file.size,
      durationSeconds: uploadResult.duration || Math.ceil(file.size / 16000), // Estimación si no hay duración
    });
  }

  @Post(':id/upload-cover')
  @ApiOperation({ summary: 'Subir carátula para un anuncio' })
  @ApiParam({ name: 'id', description: 'ID del anuncio' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
      },
    },
  })
  @UseInterceptors(FileInterceptor('file'))
  @ApiResponse({ status: 200, description: 'Carátula subida exitosamente' })
  async uploadCover(
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('Archivo de imagen requerido');
    }

    // Validar tipo de archivo
    const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowedMimeTypes.includes(file.mimetype)) {
      throw new BadRequestException('Tipo de archivo no permitido. Use JPG, PNG o WebP');
    }

    // Validar tamaño (máx 2MB)
    const maxSize = 2 * 1024 * 1024; // 2MB
    if (file.size > maxSize) {
      throw new BadRequestException('El archivo es demasiado grande. Máximo 2MB');
    }

    // Subir archivo usando el servicio de almacenamiento
    const uploadResult = await this.adsStorageService.uploadCoverImage(file, id);

    // Actualizar anuncio con la URL de la carátula
    return this.adsService.update(id, {
      coverImageUrl: uploadResult.url,
    });
  }

  @Get(':id/stats')
  @ApiOperation({ summary: 'Obtener estadísticas de un anuncio' })
  @ApiParam({ name: 'id', description: 'ID del anuncio' })
  @ApiResponse({ status: 200, description: 'Estadísticas obtenidas exitosamente' })
  async getStats(@Param('id') id: string) {
    return this.adsService.getStats(id);
  }
}




