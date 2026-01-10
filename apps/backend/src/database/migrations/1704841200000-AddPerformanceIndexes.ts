import { MigrationInterface, QueryRunner } from "typeorm";

export class AddPerformanceIndexes1704841200000 implements MigrationInterface {
    name = 'AddPerformanceIndexes1704841200000'

    public async up(queryRunner: QueryRunner): Promise<void> {
        // Índice para búsquedas por status y fileUrl (muy usado en recomendaciones)
        await queryRunner.query(`
            CREATE INDEX "IDX_song_status_fileurl" 
            ON "songs" ("status", "fileUrl") 
            WHERE "status" = 'published' AND "fileUrl" IS NOT NULL AND "fileUrl" != ''
        `);

        // Índice para búsquedas por artista (muy usado en afinidad)
        await queryRunner.query(`
            CREATE INDEX "IDX_song_artist_status" 
            ON "songs" ("artistId", "status") 
            WHERE "status" = 'published'
        `);

        // Índice para búsquedas por género
        await queryRunner.query(`
            CREATE INDEX "IDX_song_genreid_status" 
            ON "songs" ("genreId", "status") 
            WHERE "status" = 'published'
        `);

        // Índice en play_history para cálculo de afinidad
        await queryRunner.query(`
            CREATE INDEX "IDX_playhistory_user_createdat" 
            ON "play_history" ("userId", "createdAt" DESC)
        `);

        // Índice en song_likes para afinidad
        await queryRunner.query(`
            CREATE INDEX "IDX_songlikes_user_song" 
            ON "song_likes" ("userId", "songId")
        `);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`DROP INDEX "IDX_song_status_fileurl"`);
        await queryRunner.query(`DROP INDEX "IDX_song_artist_status"`);
        await queryRunner.query(`DROP INDEX "IDX_song_genreid_status"`);
        await queryRunner.query(`DROP INDEX "IDX_playhistory_user_createdat"`);
        await queryRunner.query(`DROP INDEX "IDX_songlikes_user_song"`);
    }
}
