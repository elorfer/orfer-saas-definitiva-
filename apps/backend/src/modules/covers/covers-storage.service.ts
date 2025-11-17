import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as path from 'path';
import * as fs from 'fs';
import { promisify } from 'util';
import { v4 as uuidv4 } from 'uuid';
import { FileValidationService } from '../../common/services/file-validation.service';
import { ImageProcessingService } from '../../common/services/image-processing.service';

/**
 * Servicio de almacenamiento local para portadas de canciones.
 * Diseñado para ser fácilmente intercambiable con S3Service en el futuro.
 */
@Injectable()
export class CoversStorageService {
  private readonly logger = new Logger(CoversStorageService.name);
  private readonly uploadsDir: string;
  private readonly coversDir: string;
  private readonly baseUrl: string;

  constructor(
    private readonly configService: ConfigService,
    private readonly fileValidationService: FileValidationService,
    private readonly imageProcessingService: ImageProcessingService,
  ) {
    // Directorio base de uploads
    this.uploadsDir = path.join(process.cwd(), 'uploads');
    this.coversDir = path.join(this.uploadsDir, 'covers');
    // Usar APP_URL o construir desde PORT y HOST, con fallback al puerto correcto (3001)
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
    if (!fs.existsSync(this.coversDir)) {
      fs.mkdirSync(this.coversDir, { recursive: true });
    }
  }

  /**
   * Sube una imagen de portada al almacenamiento local
   * @param file Archivo de Multer (imagen)
   * @param userId ID del usuario que sube el archivo (opcional)
   * @returns URL pública del archivo y nombre del archivo guardado
   */
  async uploadCoverImage(
    file: Express.Multer.File,
    userId?: string,
  ): Promise<{ url: string; key: string; fileName: string }> {
    try {
      // Validación centralizada usando el servicio (incluye validación de existencia, tipo y tamaño)
      this.logger.log(`🔍 Validando imagen: ${file.originalname} (${(file.size / 1024 / 1024).toFixed(2)} MB)`);
      this.fileValidationService.validateImageFile(file, 'cover');

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
      } else {
        this.logger.log(`ℹ️ Imagen sin comprimir (sharp no disponible o sin cambios)`);
      }

      // Generar nombre único para el archivo
      const fileExtension = path.extname(file.originalname) || this.getExtensionFromMimeType(file.mimetype);
      const uniqueFileName = `${uuidv4()}${fileExtension}`;
      const filePath = path.join(this.coversDir, uniqueFileName);

      // Guardar archivo comprimido
      this.logger.log(`💾 Guardando portada: ${uniqueFileName}`);
      await promisify(fs.writeFile)(filePath, processedImage.buffer);
      this.logger.log(`✅ Portada guardada: ${filePath}`);

      // Construir URL pública
      const publicUrl = `${this.baseUrl}/uploads/covers/${uniqueFileName}`;
      const key = `covers/${uniqueFileName}`;

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
   * Elimina un archivo de portada del almacenamiento local
   * @param key Clave del archivo (ej: "covers/filename.png")
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
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp',
    };

    return mimeToExt[mimeType] || '.jpg';
  }

  /**
   * Obtiene la URL pública de un archivo
   * @param key Clave del archivo (ej: "covers/filename.png")
   */
  getPublicUrl(key: string): string {
    // Si la key ya tiene el prefijo "uploads/", usarla tal cual
    if (key.startsWith('uploads/')) {
      return `${this.baseUrl}/${key}`;
    }
    // Si la key es solo "covers/...", agregar el prefijo "uploads/"
    if (key.startsWith('covers/')) {
      return `${this.baseUrl}/uploads/${key}`;
    }
    // Para cualquier otro caso, agregar "uploads/covers/"
    return `${this.baseUrl}/uploads/covers/${key}`;
  }
}

