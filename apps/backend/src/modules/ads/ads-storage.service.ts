import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as path from 'path';
import * as fs from 'fs';
import { promisify } from 'util';
import { v4 as uuidv4 } from 'uuid';
import { FileValidationService } from '../../common/services/file-validation.service';
import { AudioMetadataService } from '../../common/services/audio-metadata.service';
import { ImageProcessingService } from '../../common/services/image-processing.service';

/**
 * Interfaz para abstraer el almacenamiento (permite cambiar fácilmente entre Local y S3)
 */
export interface IAdsStorageService {
  uploadAudioFile(
    file: Express.Multer.File,
    adId: string,
  ): Promise<{ url: string; key: string; fileName: string; duration: number; metadata?: any }>;
  
  uploadCoverImage(
    file: Express.Multer.File,
    adId: string,
  ): Promise<{ url: string; key: string; fileName: string }>;
  
  deleteFile(key: string): Promise<void>;
  
  getPublicUrl(key: string): string;
}

/**
 * Servicio de almacenamiento local para archivos de anuncios.
 * Diseñado para ser fácilmente intercambiable con S3Service en el futuro.
 * 
 * Para migrar a S3:
 * 1. Crear AdsS3StorageService que implemente IAdsStorageService
 * 2. Cambiar la inyección en AdsModule
 * 3. No se requiere cambiar AdsController ni AdsService
 */
@Injectable()
export class AdsLocalStorageService implements IAdsStorageService {
  private readonly logger = new Logger(AdsLocalStorageService.name);
  private readonly uploadsDir: string;
  private readonly adsDir: string;
  private readonly adsAudioDir: string;
  private readonly adsCoversDir: string;
  private readonly baseUrl: string;
  private readonly isDevelopment = process.env.NODE_ENV !== 'production';

  constructor(
    private readonly configService: ConfigService,
    private readonly fileValidationService: FileValidationService,
    private readonly audioMetadataService: AudioMetadataService,
    private readonly imageProcessingService: ImageProcessingService,
  ) {
    // Directorio base de uploads
    this.uploadsDir = path.join(process.cwd(), 'uploads');
    this.adsDir = path.join(this.uploadsDir, 'ads');
    this.adsAudioDir = path.join(this.adsDir, 'audio');
    this.adsCoversDir = path.join(this.adsDir, 'covers');
    
    const port = this.configService.get<number>('PORT') || 3001;
    const host = this.configService.get<string>('HOST') || 'localhost';
    const appUrl = this.configService.get<string>('APP_URL');
    this.baseUrl = appUrl || `http://${host === '0.0.0.0' ? 'localhost' : host}:${port}`;

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
    if (!fs.existsSync(this.adsDir)) {
      fs.mkdirSync(this.adsDir, { recursive: true });
    }
    if (!fs.existsSync(this.adsAudioDir)) {
      fs.mkdirSync(this.adsAudioDir, { recursive: true });
    }
    if (!fs.existsSync(this.adsCoversDir)) {
      fs.mkdirSync(this.adsCoversDir, { recursive: true });
    }
  }

  /**
   * Sube un archivo de audio de anuncio al almacenamiento local
   * @param file Archivo de Multer
   * @param adId ID del anuncio (para organización)
   * @returns URL pública del archivo, nombre del archivo guardado y metadatos
   */
  async uploadAudioFile(
    file: Express.Multer.File,
    adId: string,
  ): Promise<{ url: string; key: string; fileName: string; duration: number; metadata?: any }> {
    try {
      // Validar que el archivo existe
      if (!file) {
        throw new BadRequestException('Archivo de audio requerido');
      }

      // Validar tipo de archivo (solo tipos permitidos para anuncios)
      const allowedMimeTypes = ['audio/mpeg', 'audio/mp3', 'audio/aac', 'audio/ogg'];
      if (!allowedMimeTypes.includes(file.mimetype)) {
        throw new BadRequestException('Tipo de archivo no permitido. Use MP3, AAC u OGG');
      }

      // Validar que el buffer existe y tiene contenido
      if (!file.buffer || file.buffer.length === 0) {
        this.logger.error('❌ ERROR CRÍTICO: El buffer del archivo está vacío o no existe');
        throw new BadRequestException('El archivo de audio no tiene contenido válido');
      }

      // Validar tamaño específico para anuncios (máx 5MB)
      const maxSize = 5 * 1024 * 1024; // 5MB
      if (file.size > maxSize) {
        throw new BadRequestException('El archivo es demasiado grande. Máximo 5MB para anuncios');
      }

      // Extraer metadatos del audio
      let duration = 0;
      let metadata: any = undefined;
      
      try {
        if (this.isDevelopment) {
          this.logger.log(`🔍 Extrayendo metadatos del audio del anuncio: ${file.originalname}`);
        }
        
        const audioMetadata = await this.audioMetadataService.extractMetadata(
          file.buffer,
          file.mimetype,
        );
        
        duration = audioMetadata.duration;
        metadata = audioMetadata;
        
        if (duration > 0) {
          if (this.isDevelopment) {
            this.logger.log(`✅ Metadatos extraídos: duración=${duration}s`);
          }
        } else {
          this.logger.warn('⚠️ No se pudo extraer duración del audio (duración = 0)');
        }
      } catch (error) {
        this.logger.error(`❌ Error al extraer metadatos: ${error.message}`);
        // Continuar sin metadatos si falla
        this.logger.warn('⚠️ Continuando sin metadatos (duración = 0)');
      }

      // Generar nombre único para el archivo
      const fileExtension = path.extname(file.originalname) || this.getExtensionFromMimeType(file.mimetype);
      const uniqueFileName = `${uuidv4()}${fileExtension}`;
      const filePath = path.join(this.adsAudioDir, uniqueFileName);

      // Guardar archivo
      if (this.isDevelopment) {
        this.logger.log(`💾 Guardando audio de anuncio: ${uniqueFileName}`);
      }
      await promisify(fs.writeFile)(filePath, file.buffer);
      if (this.isDevelopment) {
        this.logger.log(`✅ Audio guardado: ${filePath}`);
      }

      // Construir URL pública
      const publicUrl = `${this.baseUrl}/uploads/ads/audio/${uniqueFileName}`;
      const key = `ads/audio/${uniqueFileName}`;

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
      throw new BadRequestException(`Error al subir archivo de audio: ${error.message}`);
    }
  }

  /**
   * Sube una imagen de carátula de anuncio al almacenamiento local
   * @param file Archivo de Multer (imagen)
   * @param adId ID del anuncio (para organización)
   * @returns URL pública del archivo y nombre del archivo guardado
   */
  async uploadCoverImage(
    file: Express.Multer.File,
    adId: string,
  ): Promise<{ url: string; key: string; fileName: string }> {
    try {
      // Validar que el archivo existe
      if (!file) {
        throw new BadRequestException('Archivo de imagen requerido');
      }

      // Validar tipo de archivo (solo tipos permitidos para anuncios)
      const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp'];
      if (!allowedMimeTypes.includes(file.mimetype)) {
        throw new BadRequestException('Tipo de archivo no permitido. Use JPG, PNG o WebP');
      }

      this.logger.log(`🔍 Validando imagen de anuncio: ${file.originalname} (${(file.size / 1024 / 1024).toFixed(2)} MB)`);

      // Validar tamaño específico para anuncios (máx 2MB)
      const maxSize = 2 * 1024 * 1024; // 2MB
      if (file.size > maxSize) {
        throw new BadRequestException('El archivo es demasiado grande. Máximo 2MB para carátulas de anuncios');
      }

      // Validar dimensiones de la imagen
      this.logger.log('📐 Validando dimensiones de la imagen...');
      const dimensions = await this.imageProcessingService.validateDimensions(file.buffer);
      if (dimensions.width > 0 && dimensions.height > 0) {
        this.logger.log(`✅ Dimensiones válidas: ${dimensions.width}x${dimensions.height}px`);
      }

      // Comprimir y optimizar la imagen
      this.logger.log('🗜️ Comprimiendo imagen...');
      const processedImage = await this.imageProcessingService.compressImage(
        file.buffer,
        file.mimetype,
      );
      
      if (processedImage.size < processedImage.originalSize) {
        const reduction = ((processedImage.originalSize - processedImage.size) / processedImage.originalSize) * 100;
        this.logger.log(`✅ Imagen comprimida: ${(processedImage.originalSize / 1024 / 1024).toFixed(2)} MB → ${(processedImage.size / 1024 / 1024).toFixed(2)} MB (${reduction.toFixed(1)}% reducción)`);
      }

      // Generar nombre único para el archivo
      const fileExtension = path.extname(file.originalname) || this.getExtensionFromMimeType(file.mimetype);
      const uniqueFileName = `${uuidv4()}${fileExtension}`;
      const filePath = path.join(this.adsCoversDir, uniqueFileName);

      // Guardar archivo comprimido
      this.logger.log(`💾 Guardando carátula de anuncio: ${uniqueFileName}`);
      await promisify(fs.writeFile)(filePath, processedImage.buffer);
      this.logger.log(`✅ Carátula guardada: ${filePath}`);

      // Construir URL pública
      const publicUrl = `${this.baseUrl}/uploads/ads/covers/${uniqueFileName}`;
      const key = `ads/covers/${uniqueFileName}`;

      return {
        url: publicUrl,
        key,
        fileName: uniqueFileName,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException(`Error al subir imagen: ${error.message}`);
    }
  }

  /**
   * Elimina un archivo del almacenamiento local
   * @param key Clave del archivo (ej: "ads/audio/filename.mp3" o "ads/covers/filename.jpg")
   */
  async deleteFile(key: string): Promise<void> {
    try {
      const filePath = path.join(this.uploadsDir, key);
      
      if (fs.existsSync(filePath)) {
        await promisify(fs.unlink)(filePath);
        this.logger.log(`✅ Archivo eliminado: ${filePath}`);
      } else {
        this.logger.warn(`⚠️ Archivo no encontrado: ${filePath}`);
        // No lanzar error si el archivo no existe (puede haber sido eliminado previamente)
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
      // Audio
      'audio/mpeg': '.mp3',
      'audio/mp3': '.mp3',
      'audio/aac': '.aac',
      'audio/ogg': '.ogg',
      // Imágenes
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp',
    };

    return mimeToExt[mimeType] || (mimeType.startsWith('audio/') ? '.mp3' : '.jpg');
  }

  /**
   * Obtiene la URL pública de un archivo
   * @param key Clave del archivo
   */
  getPublicUrl(key: string): string {
    // Si la key ya tiene el prefijo "uploads/", usarla tal cual
    if (key.startsWith('uploads/')) {
      return `${this.baseUrl}/${key}`;
    }
    // Si la key es solo "ads/...", agregar el prefijo "uploads/"
    if (key.startsWith('ads/')) {
      return `${this.baseUrl}/uploads/${key}`;
    }
    // Para cualquier otro caso, agregar "uploads/ads/"
    return `${this.baseUrl}/uploads/ads/${key}`;
  }
}

/**
 * Servicio de almacenamiento S3 para archivos de anuncios.
 * 
 * TODO: Implementar cuando se migre a S3.
 * 
 * Ejemplo de implementación:
 * 
 * @Injectable()
 * export class AdsS3StorageService implements IAdsStorageService {
 *   constructor(private readonly s3Service: S3Service) {}
 * 
 *   async uploadAudioFile(file: Express.Multer.File, adId: string) {
 *     return this.s3Service.uploadFile(file, 'ads/audio', adId);
 *   }
 * 
 *   async uploadCoverImage(file: Express.Multer.File, adId: string) {
 *     return this.s3Service.uploadFile(file, 'ads/covers', adId);
 *   }
 * 
 *   async deleteFile(key: string) {
 *     return this.s3Service.deleteFile(key);
 *   }
 * 
 *   getPublicUrl(key: string) {
 *     return this.s3Service.getCloudFrontUrl(key);
 *   }
 * }
 */

