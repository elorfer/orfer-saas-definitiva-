import { Injectable, BadRequestException, Logger } from '@nestjs/common';

// Importar sharp de manera estática con manejo de errores
let sharpModule: any = null;
let sharpAvailable = false;
let sharpFunction: any = null;

// Intentar cargar sharp de forma lazy y silenciosa
// sharp es OPCIONAL - el servicio funciona sin él guardando imágenes sin comprimir
// NO mostrar errores aquí - solo silenciar y continuar sin sharp
try {
  // Intentar resolver sharp primero (más rápido que require directo)
  try {
    require.resolve('sharp');
    // Si puede resolverse, intentar cargarlo
    sharpModule = require('sharp');
    
    // En versiones recientes de sharp (0.30+), puede exportarse de diferentes maneras
    // Intentar obtener la función correcta
    if (typeof sharpModule === 'function') {
      sharpFunction = sharpModule;
      sharpAvailable = true;
    } else if (sharpModule && typeof sharpModule.default === 'function') {
      sharpFunction = sharpModule.default;
      sharpAvailable = true;
    } else if (sharpModule && typeof sharpModule === 'object') {
      // Buscar la función en el objeto
      if ('default' in sharpModule && typeof sharpModule.default === 'function') {
        sharpFunction = sharpModule.default;
        sharpAvailable = true;
      } else {
        // Buscar cualquier propiedad que sea una función
        for (const key in sharpModule) {
          if (typeof sharpModule[key] === 'function') {
            sharpFunction = sharpModule[key];
            sharpAvailable = true;
            break;
          }
        }
      }
    }
    
    // Verificar que realmente tengamos una función válida
    if (sharpAvailable && typeof sharpFunction !== 'function') {
      sharpAvailable = false;
      sharpFunction = null;
    }
  } catch {
    // sharp no está instalado o no se puede cargar - está bien, es opcional
    // NO mostrar error - el servicio funcionará sin compresión
    sharpAvailable = false;
    sharpFunction = null;
  }
} catch (e: any) {
  // Silenciar completamente cualquier error relacionado con sharp
  // sharp es opcional y el servicio funciona sin él
  // El constructor mostrará un warning informativo pero NO bloqueará el servidor
  sharpAvailable = false;
  sharpFunction = null;
}

/**
 * Servicio para procesar y comprimir imágenes
 * Usa sharp si está disponible, sino guarda sin comprimir
 */
@Injectable()
export class ImageProcessingService {
  private readonly logger = new Logger(ImageProcessingService.name);
  private readonly sharpAvailable: boolean;

  constructor() {
    this.sharpAvailable = sharpAvailable;
    if (this.sharpAvailable) {
      this.logger.log('Sharp disponible - compresión de imágenes habilitada');
    } else {
      this.logger.warn('Sharp no está instalado - las imágenes se guardarán sin comprimir. Ejecuta: npm install sharp');
    }
  }

  /**
   * Obtiene la instancia de sharp de manera segura
   */
  private getSharp() {
    if (!this.sharpAvailable || !sharpFunction) {
      throw new Error('Sharp no está disponible');
    }
    
    // Verificar que sea una función
    if (typeof sharpFunction !== 'function') {
      throw new Error('Sharp no es una función válida');
    }
    
    return sharpFunction;
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
      const sharp = this.getSharp();
      
      // Verificar que sharp sea realmente una función
      if (typeof sharp !== 'function') {
        this.logger.error('Sharp no es una función válida en compressImage');
        throw new Error('Sharp no está configurado correctamente');
      }
      
      const originalSize = fileBuffer.length;

      // Crear instancia de sharp con el buffer
      const sharpInstance = sharp(fileBuffer);

      // Obtener metadatos de la imagen
      const metadata = await sharpInstance.metadata();

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
      const finalSharpInstance = sharp(compressedBuffer);
      const finalMetadata = await finalSharpInstance.metadata();

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
      // Sin sharp, no podemos validar dimensiones - pero no fallamos, solo advertimos
      this.logger.warn('No se pueden validar dimensiones sin sharp - saltando validación');
      // Retornar dimensiones por defecto para que el proceso continúe
      return { width: 0, height: 0 };
    }

    try {
      const sharp = this.getSharp();
      
      // Verificar que sharp sea realmente una función antes de usarla
      if (typeof sharp !== 'function') {
        this.logger.error('Sharp no es una función válida');
        throw new Error('Sharp no está configurado correctamente');
      }
      
      // Crear instancia de sharp con el buffer
      const sharpInstance = sharp(fileBuffer);
      
      // Obtener metadatos
      const metadata = await sharpInstance.metadata();

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
      // Si es un error de sharp, hacer que la validación sea opcional
      this.logger.error(`Error al validar dimensiones con sharp: ${error.message}`);
      this.logger.warn('Continuando sin validación de dimensiones');
      return { width: 0, height: 0 };
    }
  }
}




