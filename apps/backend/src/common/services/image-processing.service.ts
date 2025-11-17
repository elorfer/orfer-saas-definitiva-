import { Injectable, BadRequestException, Logger } from '@nestjs/common';

/**
 * Servicio para procesar y comprimir imágenes
 * Usa sharp si está disponible, sino guarda sin comprimir
 */
@Injectable()
export class ImageProcessingService {
  private readonly logger = new Logger(ImageProcessingService.name);
  private readonly sharpAvailable: boolean;

  constructor() {
    // Verificar si sharp está disponible
    try {
      require('sharp');
      this.sharpAvailable = true;
      this.logger.log('Sharp disponible - compresión de imágenes habilitada');
    } catch (e) {
      this.sharpAvailable = false;
      this.logger.warn('Sharp no está instalado - las imágenes se guardarán sin comprimir. Ejecuta: npm install sharp');
    }
  }

  /**
   * Comprime y optimiza una imagen
   * @param fileBuffer Buffer de la imagen original
   * @param mimeType Tipo MIME de la imagen
   * @returns Buffer comprimido y metadatos
   */
  async compressImage(
    fileBuffer: Buffer,
    mimeType: string,
  ): Promise<{
    buffer: Buffer;
    width: number;
    height: number;
    size: number; // tamaño del buffer comprimido
    originalSize: number; // tamaño original
  }> {
    if (!this.sharpAvailable) {
      // Si sharp no está disponible, retornar imagen original
      return {
        buffer: fileBuffer,
        width: 0,
        height: 0,
        size: fileBuffer.length,
        originalSize: fileBuffer.length,
      };
    }

    try {
      const sharp = require('sharp');
      const originalSize = fileBuffer.length;

      // Obtener metadatos de la imagen
      const metadata = await sharp(fileBuffer).metadata();

      // Comprimir y redimensionar si es necesario
      let processedImage = sharp(fileBuffer);

      // Redimensionar si es muy grande (máximo 1200x1200)
      if (metadata.width > 1200 || metadata.height > 1200) {
        processedImage = processedImage.resize(1200, 1200, {
          fit: 'inside',
          withoutEnlargement: true,
        });
      }

      // Comprimir según el tipo
      let compressedBuffer: Buffer;
      if (mimeType === 'image/jpeg' || mimeType === 'image/jpg') {
        compressedBuffer = await processedImage
          .jpeg({ quality: 85, progressive: true })
          .toBuffer();
      } else if (mimeType === 'image/png') {
        compressedBuffer = await processedImage
          .png({ quality: 85, compressionLevel: 9 })
          .toBuffer();
      } else if (mimeType === 'image/webp') {
        compressedBuffer = await processedImage
          .webp({ quality: 85 })
          .toBuffer();
      } else {
        // Para otros formatos, retornar original
        compressedBuffer = fileBuffer;
      }

      // Obtener dimensiones finales
      const finalMetadata = await sharp(compressedBuffer).metadata();

      const compressionRatio = ((originalSize - compressedBuffer.length) / originalSize) * 100;
      this.logger.log(
        `Imagen comprimida: ${originalSize} bytes → ${compressedBuffer.length} bytes (${compressionRatio.toFixed(1)}% reducción)`,
      );

      return {
        buffer: compressedBuffer,
        width: finalMetadata.width || 0,
        height: finalMetadata.height || 0,
        size: compressedBuffer.length,
        originalSize,
      };
    } catch (error) {
      this.logger.error(`Error al comprimir imagen: ${error.message}`);
      // Si falla la compresión, retornar original
      return {
        buffer: fileBuffer,
        width: 0,
        height: 0,
        size: fileBuffer.length,
        originalSize: fileBuffer.length,
      };
    }
  }

  /**
   * Valida dimensiones de una imagen
   * @param fileBuffer Buffer de la imagen
   * @param minWidth Ancho mínimo
   * @param minHeight Alto mínimo
   * @param maxWidth Ancho máximo
   * @param maxHeight Alto máximo
   */
  async validateDimensions(
    fileBuffer: Buffer,
    minWidth: number = 300,
    minHeight: number = 300,
    maxWidth: number = 2000,
    maxHeight: number = 2000,
  ): Promise<{ width: number; height: number }> {
    if (!this.sharpAvailable) {
      // Sin sharp, no podemos validar dimensiones
      this.logger.warn('No se pueden validar dimensiones sin sharp');
      return { width: 0, height: 0 };
    }

    try {
      const sharp = require('sharp');
      const metadata = await sharp(fileBuffer).metadata();

      if (!metadata.width || !metadata.height) {
        throw new BadRequestException('No se pudieron leer las dimensiones de la imagen');
      }

      if (metadata.width < minWidth || metadata.height < minHeight) {
        throw new BadRequestException(
          `Imagen muy pequeña. Mínimo: ${minWidth}x${minHeight}px. Actual: ${metadata.width}x${metadata.height}px`,
        );
      }

      if (metadata.width > maxWidth || metadata.height > maxHeight) {
        throw new BadRequestException(
          `Imagen muy grande. Máximo: ${maxWidth}x${maxHeight}px. Actual: ${metadata.width}x${metadata.height}px`,
        );
      }

      return {
        width: metadata.width,
        height: metadata.height,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException(`Error al validar dimensiones: ${error.message}`);
    }
  }
}




