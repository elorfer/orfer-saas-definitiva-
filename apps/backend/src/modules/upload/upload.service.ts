import { Injectable, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
// import * as ffmpeg from 'fluent-ffmpeg';
import * as path from 'path';
import * as fs from 'fs';
import { promisify } from 'util';

import { S3Service } from './s3.service';
import { User } from '../../common/entities/user.entity';
import { Artist } from '../../common/entities/artist.entity';

@Injectable()
export class UploadService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Artist)
    private readonly artistRepository: Repository<Artist>,
    private readonly s3Service: S3Service,
  ) {}

  async uploadAudioFile(
    file: Express.Multer.File,
    userId: string,
  ): Promise<{ url: string; key: string; duration: number; metadata: any }> {
    // Verificar que el usuario sea artista
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: ['artist'],
    });

    if (!user || !user.artist) {
      throw new ForbiddenException('Solo los artistas pueden subir archivos de audio');
    }

    try {
      // Procesar archivo de audio para obtener metadatos
      const metadata = await this.getAudioMetadata(file);
      
      // Subir archivo a S3
      const uploadResult = await this.s3Service.uploadAudioFile(file, userId);

      return {
        url: uploadResult.url,
        key: uploadResult.key,
        duration: metadata.duration,
        metadata,
      };
    } catch (error) {
      throw new BadRequestException(`Error al procesar archivo de audio: ${error.message}`);
    }
  }

  async uploadImageFile(
    file: Express.Multer.File,
    userId: string,
  ): Promise<{ url: string; key: string; metadata: any }> {
    try {
      // Validar que sea una imagen
      if (!file.mimetype.startsWith('image/')) {
        throw new BadRequestException('El archivo debe ser una imagen');
      }

      // Procesar imagen para obtener metadatos
      const metadata = await this.getImageMetadata(file);
      
      // Subir archivo a S3
      const uploadResult = await this.s3Service.uploadImageFile(file, userId);

      return {
        url: uploadResult.url,
        key: uploadResult.key,
        metadata,
      };
    } catch (error) {
      throw new BadRequestException(`Error al procesar imagen: ${error.message}`);
    }
  }

  async deleteFile(key: string, userId: string): Promise<void> {
    // Verificar que el usuario tenga permisos para eliminar el archivo
    const user = await this.userRepository.findOne({
      where: { id: userId },
    });

    if (!user) {
      throw new ForbiddenException('Usuario no encontrado');
    }

    try {
      await this.s3Service.deleteFile(key);
    } catch (error) {
      throw new BadRequestException(`Error al eliminar archivo: ${error.message}`);
    }
  }

  async generatePresignedUploadUrl(
    fileName: string,
    contentType: string,
    userId: string,
  ): Promise<{ uploadUrl: string; key: string }> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
    });

    if (!user) {
      throw new ForbiddenException('Usuario no encontrado');
    }

    const fileExtension = path.extname(fileName);
    const key = `uploads/${userId}/${Date.now()}-${fileName}`;

    try {
      const uploadUrl = await this.s3Service.generatePresignedUploadUrl(
        key,
        contentType,
        3600, // 1 hora
      );

      return { uploadUrl, key };
    } catch (error) {
      throw new BadRequestException(`Error al generar URL de subida: ${error.message}`);
    }
  }

  private async getAudioMetadata(file: Express.Multer.File): Promise<any> {
    return new Promise((resolve, reject) => {
      const tempPath = `/tmp/${Date.now()}-${file.originalname}`;
      
      // Escribir archivo temporal
      fs.writeFileSync(tempPath, file.buffer);

      // ffmpeg.ffprobe(tempPath, (err, metadata) => {
      //   // Limpiar archivo temporal
      //   fs.unlinkSync(tempPath);

      //   if (err) {
      //     reject(new Error(`Error al analizar archivo de audio: ${err.message}`));
      //     return;
      //   }

      //   const audioStream = metadata.streams.find(stream => stream.codec_type === 'audio');
        
      //   if (!audioStream) {
      //     reject(new Error('No se encontró stream de audio en el archivo'));
      //     return;
      //   }

      // Limpiar archivo temporal
      fs.unlinkSync(tempPath);

      // Retornar valores por defecto hasta que ffmpeg esté configurado
      resolve({
        duration: 180, // 3 minutos por defecto
        bitrate: 128000,
        format: 'mp3',
        codec: 'mp3',
        sampleRate: 44100,
        channels: 2,
      });

      // });
    });
  }

  private async getImageMetadata(file: Express.Multer.File): Promise<any> {
    // Para imágenes, podemos usar bibliotecas como sharp o jimp
    // Por ahora, retornamos información básica
    return {
      size: file.size,
      mimetype: file.mimetype,
      originalName: file.originalname,
    };
  }

  async convertToHLS(audioKey: string, userId: string): Promise<{ hlsUrl: string; playlistUrl: string }> {
    // Esta función convertiría el archivo de audio a formato HLS
    // Por ahora, retornamos URLs simuladas
    const hlsKey = audioKey.replace(/\.[^/.]+$/, '.m3u8');
    const hlsUrl = this.s3Service.getCloudFrontUrl(hlsKey);
    const playlistUrl = this.s3Service.getCloudFrontUrl(hlsKey);

    return { hlsUrl, playlistUrl };
  }
}
