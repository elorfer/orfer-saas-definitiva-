import {
  Controller,
  Post,
  Delete,
  Param,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Body,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';

import { UploadService } from './upload.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User, UserRole } from '../../common/entities/user.entity';

@ApiTags('upload')
@Controller('upload')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class UploadController {
  constructor(private readonly uploadService: UploadService) {}

  @Post('audio')
  @Roles(UserRole.ARTIST)
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Subir archivo de audio' })
  @ApiConsumes('multipart/form-data')
  @ApiResponse({ status: 201, description: 'Archivo de audio subido exitosamente' })
  @ApiResponse({ status: 400, description: 'Error en el archivo o formato no válido' })
  @ApiResponse({ status: 403, description: 'Solo artistas pueden subir archivos de audio' })
  async uploadAudio(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: User,
  ) {
    if (!file) {
      throw new BadRequestException('No se proporcionó archivo');
    }

    // Validar tipo de archivo
    const allowedAudioTypes = [
      'audio/mpeg',
      'audio/mp3',
      'audio/wav',
      'audio/flac',
      'audio/aac',
      'audio/ogg',
    ];

    if (!allowedAudioTypes.includes(file.mimetype)) {
      throw new BadRequestException('Tipo de archivo de audio no permitido');
    }

    return this.uploadService.uploadAudioFile(file, user.id);
  }

  @Post('image')
  @UseInterceptors(FileInterceptor('file'))
  @ApiOperation({ summary: 'Subir imagen' })
  @ApiConsumes('multipart/form-data')
  @ApiResponse({ status: 201, description: 'Imagen subida exitosamente' })
  @ApiResponse({ status: 400, description: 'Error en la imagen o formato no válido' })
  async uploadImage(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: User,
  ) {
    if (!file) {
      throw new BadRequestException('No se proporcionó archivo');
    }

    // Validar tipo de archivo
    const allowedImageTypes = [
      'image/jpeg',
      'image/png',
      'image/webp',
    ];

    if (!allowedImageTypes.includes(file.mimetype)) {
      throw new BadRequestException('Tipo de imagen no permitido');
    }

    return this.uploadService.uploadImageFile(file, user.id);
  }

  @Post('presigned-url')
  @ApiOperation({ summary: 'Generar URL firmada para subida directa' })
  @ApiResponse({ status: 201, description: 'URL firmada generada exitosamente' })
  async generatePresignedUrl(
    @Body() body: { fileName: string; contentType: string },
    @CurrentUser() user: User,
  ) {
    return this.uploadService.generatePresignedUploadUrl(
      body.fileName,
      body.contentType,
      user.id,
    );
  }

  @Delete(':key')
  @ApiOperation({ summary: 'Eliminar archivo' })
  @ApiResponse({ status: 200, description: 'Archivo eliminado exitosamente' })
  @ApiResponse({ status: 404, description: 'Archivo no encontrado' })
  async deleteFile(
    @Param('key') key: string,
    @CurrentUser() user: User,
  ) {
    await this.uploadService.deleteFile(key, user.id);
    return { message: 'Archivo eliminado exitosamente' };
  }
}









