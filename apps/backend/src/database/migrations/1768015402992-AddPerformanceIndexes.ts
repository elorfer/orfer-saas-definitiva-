import { MigrationInterface, QueryRunner } from "typeorm";

/**
 * 🚀 ÍNDICE DE PERFORMANCE BÁSICO PARA RECOMENDACIONES
 * Solo el más crítico - status de canciones
 */
export class AddPerformanceIndexes1768015402992 implements MigrationInterface {

    public async up(queryRunner: QueryRunner): Promise<void> {
        // 🎯 ÍNDICE: Status de canciones (el más importante)
        await queryRunner.query(`
            CREATE INDEX IF NOT EXISTS idx_songs_status 
            ON songs(status)
        `);

        console.log('✅ Índice de performance creado exitosamente');
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`DROP INDEX IF EXISTS idx_songs_status`);
        console.log('✅ Índice de performance eliminado');
    }

}
