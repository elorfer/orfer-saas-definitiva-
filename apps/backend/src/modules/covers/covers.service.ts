import { Injectable, BadRequestException } from '@nestjs/common';
import { CoversStorageService } from './covers-storage.service';

@Injectable()
export class CoversService {
  constructor(private readonly coversStorageService: CoversStorageService) {}

  /**
   * Sube una imagen de portada y retorna la URL del archivo
   * @param file Archivo de Multer
   * @param userId ID del usuario que sube el archivo (opcional)
   * @returns URL pública del archivo subido
   */
  async uploadCover(
    file: Express.Multer.File,
    userId?: string,
  ): Promise<{ url: string; fileName: string }> {
    if (!file) {
      throw new BadRequestException('No se proporcionó archivo');
    }

    try {
      // Subir archivo usando el servicio de almacenamiento
      const uploadResult = await this.coversStorageService.uploadCoverImage(file, userId);

      return {
        url: uploadResult.url,
        fileName: uploadResult.fileName,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException(`Error al subir portada: ${error.message}`);
    }
  }

  /**
   * Elimina una portada
   * @param key Clave del archivo a eliminar
   */
  async deleteCover(key: string): Promise<void> {
    await this.coversStorageService.deleteFile(key);
  }
}





