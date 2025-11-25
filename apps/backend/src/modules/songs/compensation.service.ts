import { Injectable, Logger } from '@nestjs/common';

import { LocalStorageService } from './local-storage.service';
import { CoversStorageService } from '../covers/covers-storage.service';

/**
 * Servicio de compensación (SAGA pattern)
 * Limpia archivos subidos cuando falla algún paso del proceso
 */
@Injectable()
export class CompensationService {
  private readonly logger = new Logger(CompensationService.name);
  private readonly isDevelopment = process.env.NODE_ENV !== 'production';

  constructor(
    private readonly localStorageService: LocalStorageService,
    private readonly coversStorageService: CoversStorageService,
  ) {}

  /**
   * Limpia archivos subidos (compensación)
   * @param files Objeto con las claves de archivos a eliminar
   */
  async cleanupFiles(files: {
    audioFileKey?: string;
    coverFileKey?: string;
  }): Promise<void> {
    const cleanupStart = Date.now();
    this.logger.log('🔄 Iniciando limpieza de archivos (compensación)...');

    const cleanupPromises: Promise<void>[] = [];

    // Limpiar archivo de audio
    if (files.audioFileKey) {
      cleanupPromises.push(
        this.deleteFileSafely(
          files.audioFileKey,
          'audio',
          () => this.localStorageService.deleteFile(files.audioFileKey),
        ),
      );
    }

    // Limpiar archivo de portada
    if (files.coverFileKey) {
      cleanupPromises.push(
        this.deleteFileSafely(
          files.coverFileKey,
          'cover',
          () => this.coversStorageService.deleteFile(files.coverFileKey),
        ),
      );
    }

    // Ejecutar limpieza en paralelo
    await Promise.allSettled(cleanupPromises);

    const elapsed = Date.now() - cleanupStart;
    this.logger.log(`✅ Limpieza completada en ${elapsed}ms`);
  }

  /**
   * Elimina un archivo de forma segura (no lanza excepciones)
   */
  private async deleteFileSafely(
    fileKey: string,
    type: 'audio' | 'cover',
    deleteFn: () => Promise<void>,
  ): Promise<void> {
    try {
      if (this.isDevelopment) {
        this.logger.log(`🗑️ Eliminando archivo ${type}: ${fileKey}`);
      }
      await deleteFn();
      if (this.isDevelopment) {
        this.logger.log(`✅ Archivo ${type} eliminado: ${fileKey}`);
      }
    } catch (error) {
      // No lanzar excepción - solo loggear
      // Es posible que el archivo ya no exista o haya sido eliminado
      this.logger.warn(
        `⚠️ No se pudo eliminar archivo ${type} ${fileKey}: ${error.message}`,
      );
    }
  }
}










