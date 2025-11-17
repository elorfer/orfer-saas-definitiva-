import { Injectable, BadRequestException } from '@nestjs/common';

/**
 * Servicio centralizado para validación de archivos
 * Elimina duplicación de código y centraliza la lógica de validación
 */
@Injectable()
export class FileValidationService {
  // Tipos MIME permitidos para audio
  private readonly allowedAudioTypes = [
    'audio/mpeg',
    'audio/mp3',
    'audio/wav',
    'audio/x-wav',
    'audio/m4a',
    'audio/x-m4a',
    'audio/flac',
    'audio/x-flac',
  ];

  // Tipos MIME permitidos para imágenes
  private readonly allowedImageTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/gif',
  ];

  // Límites de tamaño (en bytes)
  private readonly MAX_AUDIO_SIZE = 100 * 1024 * 1024; // 100MB
  private readonly MAX_COVER_SIZE = 5 * 1024 * 1024; // 5MB

  /**
   * Valida un archivo de audio
   * @param file Archivo a validar
   * @param fieldName Nombre del campo (para mensajes de error)
   * @throws BadRequestException si el archivo no es válido
   */
  validateAudioFile(file: Express.Multer.File, fieldName: string = 'audio'): void {
    if (!file) {
      throw new BadRequestException(`No se proporcionó archivo de audio en el campo "${fieldName}"`);
    }

    if (!file.buffer || file.buffer.length === 0) {
      throw new BadRequestException(`El archivo de audio en "${fieldName}" está vacío`);
    }

    if (!file.mimetype || !this.allowedAudioTypes.includes(file.mimetype)) {
      throw new BadRequestException(
        `Tipo de archivo de audio no permitido: ${file.mimetype}. Tipos permitidos: ${this.allowedAudioTypes.join(', ')}`,
      );
    }

    if (file.size > this.MAX_AUDIO_SIZE) {
      const maxSizeMB = this.MAX_AUDIO_SIZE / (1024 * 1024);
      throw new BadRequestException(
        `El archivo de audio excede el tamaño máximo permitido de ${maxSizeMB}MB`,
      );
    }
  }

  /**
   * Valida un archivo de imagen (portada)
   * @param file Archivo a validar
   * @param fieldName Nombre del campo (para mensajes de error)
   * @throws BadRequestException si el archivo no es válido
   */
  validateImageFile(file: Express.Multer.File, fieldName: string = 'cover'): void {
    if (!file) {
      throw new BadRequestException(`No se proporcionó archivo de imagen en el campo "${fieldName}"`);
    }

    if (!file.buffer || file.buffer.length === 0) {
      throw new BadRequestException(`El archivo de imagen en "${fieldName}" está vacío`);
    }

    if (!file.mimetype || !this.allowedImageTypes.includes(file.mimetype)) {
      throw new BadRequestException(
        `Tipo de archivo de imagen no permitido: ${file.mimetype}. Tipos permitidos: ${this.allowedImageTypes.join(', ')}`,
      );
    }

    if (file.size > this.MAX_COVER_SIZE) {
      const maxSizeMB = this.MAX_COVER_SIZE / (1024 * 1024);
      throw new BadRequestException(
        `El archivo de imagen excede el tamaño máximo permitido de ${maxSizeMB}MB`,
      );
    }
  }

  /**
   * Obtiene los tipos MIME permitidos para audio
   */
  getAllowedAudioTypes(): string[] {
    return [...this.allowedAudioTypes];
  }

  /**
   * Obtiene los tipos MIME permitidos para imágenes
   */
  getAllowedImageTypes(): string[] {
    return [...this.allowedImageTypes];
  }

  /**
   * Obtiene el límite máximo de tamaño para audio (en bytes)
   */
  getMaxAudioSize(): number {
    return this.MAX_AUDIO_SIZE;
  }

  /**
   * Obtiene el límite máximo de tamaño para portadas (en bytes)
   */
  getMaxCoverSize(): number {
    return this.MAX_COVER_SIZE;
  }
}




