import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as path from 'path';
import * as fs from 'fs';
import { promisify } from 'util';
import { v4 as uuidv4 } from 'uuid';
import { FileValidationService } from '../../common/services/file-validation.service';
import { AudioMetadataService } from '../../common/services/audio-metadata.service';

/**
 * Servicio de almacenamiento local para archivos.
 * Diseñado para ser fácilmente intercambiable con S3Service en el futuro.
 */
@Injectable()
export class LocalStorageService {
  private readonly logger = new Logger(LocalStorageService.name);
  private readonly uploadsDir: string;
  private readonly songsDir: string;
  private readonly baseUrl: string;
  private readonly isDevelopment = process.env.NODE_ENV !== 'production';

  constructor(
    private readonly configService: ConfigService,
    private readonly fileValidationService: FileValidationService,
    private readonly audioMetadataService: AudioMetadataService,
  ) {
    // Directorio base de uploads
    this.uploadsDir = path.join(process.cwd(), 'uploads');
    this.songsDir = path.join(this.uploadsDir, 'songs');
    this.baseUrl = this.configService.get<string>('APP_URL') || 'http://localhost:3000';

    // Crear directorios si no existen
    this.ensureDirectoriesExist();
  }

  /**
   * Asegura que los directorios necesarios existan
   */
  private ensureDirectoriesExist(): void {
    if (!fs.existsSync(this.uploadsDir)) {
      fs.mkdirSync(this.uploadsDir, { recursive: true });
    }
    if (!fs.existsSync(this.songsDir)) {
      fs.mkdirSync(this.songsDir, { recursive: true });
    }
  }

  /**
   * Sube un archivo de audio al almacenamiento local
   * @param file Archivo de Multer
   * @param userId ID del usuario que sube el archivo (opcional, para organización)
   * @returns URL pública del archivo, nombre del archivo guardado y metadatos
   */
  async uploadAudioFile(
    file: Express.Multer.File,
    userId?: string,
  ): Promise<{ url: string; key: string; fileName: string; duration: number; metadata?: any }> {
    try {
      // Validación centralizada usando el servicio (incluye validación de existencia, tipo y tamaño)
      this.fileValidationService.validateAudioFile(file, 'audio');

      // Validar que el buffer existe y tiene contenido ANTES de procesar
      if (!file.buffer || file.buffer.length === 0) {
        this.logger.error('❌ ERROR CRÍTICO: El buffer del archivo está vacío o no existe');
        this.logger.error(`   - file.buffer: ${file.buffer}`);
        this.logger.error(`   - file.size: ${file.size}`);
        this.logger.error(`   - file.fieldname: ${file.fieldname}`);
        throw new BadRequestException('El archivo de audio no tiene contenido válido');
      }

      // Extraer metadatos del audio ANTES de guardar el archivo
      // Esto asegura que tenemos el buffer completo en memoria
      if (this.isDevelopment) {
        this.logger.log('🔍 Extrayendo metadatos del audio...');
        this.logger.log(`   - Archivo: ${file.originalname}`);
        this.logger.log(`   - Tamaño: ${(file.size / 1024 / 1024).toFixed(2)} MB`);
        this.logger.log(`   - MIME type: ${file.mimetype}`);
        this.logger.log(`   - Buffer disponible: ${file.buffer ? 'SÍ' : 'NO'}`);
        this.logger.log(`   - Buffer size: ${file.buffer ? (file.buffer.length / 1024 / 1024).toFixed(2) + ' MB' : 'N/A'}`);
      }
      
      let duration = 0;
      let metadata: any = undefined;
      
      try {
        if (this.isDevelopment) {
          this.logger.log('   - Llamando a audioMetadataService.extractMetadata...');
        }
        const audioMetadata = await this.audioMetadataService.extractMetadata(
          file.buffer,
          file.mimetype,
        );
        if (this.isDevelopment) {
          this.logger.log(`   - Respuesta recibida: duration=${audioMetadata.duration}s`);
        }
        
        duration = audioMetadata.duration;
        metadata = audioMetadata;
        
        if (duration > 0) {
          if (this.isDevelopment) {
            this.logger.log(`✅ Metadatos extraídos: duración=${duration}s (${Math.floor(duration / 60)}:${(duration % 60).toString().padStart(2, '0')}), codec=${metadata.codec || 'unknown'}, bitrate=${metadata.bitrate || 'unknown'}`);
          }
        } else {
          this.logger.warn('⚠️ No se pudo extraer duración del audio (duración = 0)');
          if (this.isDevelopment) {
            this.logger.warn(`   - Metadatos recibidos: ${JSON.stringify(audioMetadata)}`);
            this.logger.warn(`   - Esto puede indicar que el archivo está corrupto o en un formato no soportado`);
          }
        }
      } catch (error) {
        this.logger.error(`❌ Error al extraer metadatos: ${error.message}`);
        if (this.isDevelopment) {
          this.logger.error(`   - Tipo de error: ${error.constructor?.name || 'Unknown'}`);
          if (error.stack) {
            this.logger.error(`   - Stack (primeras 5 líneas): ${error.stack.split('\n').slice(0, 5).join('\n   ')}`);
          }
        }
        // Si falla la extracción de metadatos, continuar sin ellos
        // La duración será 0 y se puede actualizar después
        this.logger.warn('⚠️ Continuando sin metadatos (duración = 0)');
      }

      // Generar nombre único para el archivo
      const fileExtension = path.extname(file.originalname) || this.getExtensionFromMimeType(file.mimetype);
      const uniqueFileName = `${uuidv4()}${fileExtension}`;
      const filePath = path.join(this.songsDir, uniqueFileName);

      // Guardar archivo DESPUÉS de extraer metadatos
      if (this.isDevelopment) {
        this.logger.log(`💾 Guardando archivo: ${uniqueFileName}`);
      }
      await promisify(fs.writeFile)(filePath, file.buffer);
      if (this.isDevelopment) {
        this.logger.log(`✅ Archivo guardado: ${filePath}`);
      }

      // Construir URL pública
      const publicUrl = `${this.baseUrl}/uploads/songs/${uniqueFileName}`;
      const key = `songs/${uniqueFileName}`;

      return {
        url: publicUrl,
        key,
        fileName: uniqueFileName,
        duration,
        metadata,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException(`Error al subir archivo: ${error.message}`);
    }
  }

  /**
   * Elimina un archivo del almacenamiento local
   * @param key Clave del archivo (ej: "songs/filename.mp3")
   */
  async deleteFile(key: string): Promise<void> {
    try {
      const filePath = path.join(this.uploadsDir, key);
      
      if (fs.existsSync(filePath)) {
        await promisify(fs.unlink)(filePath);
      } else {
        throw new BadRequestException('Archivo no encontrado');
      }
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException(`Error al eliminar archivo: ${error.message}`);
    }
  }

  /**
   * Obtiene la extensión del archivo basándose en el MIME type
   */
  private getExtensionFromMimeType(mimeType: string): string {
    const mimeToExt: Record<string, string> = {
      'audio/mpeg': '.mp3',
      'audio/mp3': '.mp3',
      'audio/wav': '.wav',
      'audio/x-wav': '.wav',
      'audio/m4a': '.m4a',
      'audio/x-m4a': '.m4a',
      'audio/flac': '.flac',
      'audio/x-flac': '.flac',
    };

    return mimeToExt[mimeType] || '.mp3';
  }


  /**
   * Obtiene la URL pública de un archivo
   * @param key Clave del archivo
   */
  getPublicUrl(key: string): string {
    return `${this.baseUrl}/${key}`;
  }
}

