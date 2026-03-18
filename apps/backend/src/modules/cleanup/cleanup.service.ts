import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { S3Service } from '../upload/s3.service';
import { DataSource } from 'typeorm';

@Injectable()
export class CleanupService {
    private readonly logger = new Logger(CleanupService.name);

    constructor(
        private readonly s3Service: S3Service,
        private readonly dataSource: DataSource,
    ) { }

    // Se ejecuta todos los días a las 3:00 AM
    @Cron(CronExpression.EVERY_DAY_AT_4AM)
    async handleOrphanedFilesCleanup() {
        this.logger.log('🧹 Iniciando limpieza de archivos huérfanos en R2...');

        // 1. Listar archivos en carpetas clave
        const imageFiles = await this.s3Service.listObjects('images/');
        const audioFiles = await this.s3Service.listObjects('audio/');

        const allFiles = [...imageFiles, ...audioFiles];
        this.logger.log(`🔍 Encontrados ${allFiles.length} archivos en total.`);

        if (allFiles.length === 0) return;

        // 2. Obtener lista blanca de archivos EN USO desde la DB
        const usedFilesResult = await this.dataSource.query(`
      SELECT profile_photo_url as url FROM artists WHERE profile_photo_url IS NOT NULL
      UNION
      SELECT cover_photo_url as url FROM artists WHERE cover_photo_url IS NOT NULL
      UNION
      SELECT cover_art_url as url FROM songs WHERE cover_art_url IS NOT NULL
      UNION
      SELECT file_url as url FROM songs WHERE file_url IS NOT NULL
      UNION
      SELECT avatar_url as url FROM users WHERE avatar_url IS NOT NULL
    `);

        // Extraer keys de las URLs
        const usedKeys = new Set(usedFilesResult.map((row: any) => {
            try {
                // Extrae el key de la URL completa (ej: .../images/xyz.jpg -> images/xyz.jpg)
                // Buscamos 'images/' o 'audio/'
                const url = row.url;
                if (!url) return null;

                let match = url.match(/(images\/.*)/);
                if (match) return match[1];

                match = url.match(/(audio\/.*)/);
                if (match) return match[1];

                return null;
            } catch (e) {
                return null; // URL inválida
            }
        }).filter(k => k !== null));

        this.logger.log(`💾 Archivos en uso legítimo: ${usedKeys.size}`);

        // 3. Identificar Huérfanos
        let deletedCount = 0;
        const now = new Date();
        const GRACE_PERIOD_MS = 24 * 60 * 60 * 1000; // 24 horas

        for (const file of allFiles) {
            const fileKey = file.Key;
            const lastModified = file.LastModified;

            // Si el archivo es nuevo (< 24h), lo ignoramos (puede ser un upload en proceso)
            if (now.getTime() - new Date(lastModified).getTime() < GRACE_PERIOD_MS) {
                continue;
            }

            // Si NO está en la lista de usados
            if (!usedKeys.has(fileKey)) {
                try {
                    this.logger.log(`🗑️ Borrando huérfano: ${fileKey}`);
                    await this.s3Service.deleteFile(fileKey);
                    deletedCount++;
                } catch (error) {
                    this.logger.error(`❌ Error borrando ${fileKey}:`, error);
                }
            }
        }

        this.logger.log(`✅ Limpieza completada. Total borrados: ${deletedCount}`);
    }
}
