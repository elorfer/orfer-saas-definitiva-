
const { DataSource } = require('typeorm');
const { config } = require('dotenv');
const path = require('path');

// Cargar variables de entorno
config({ path: path.join(__dirname, '../.env') });
config({ path: path.join(__dirname, '../.env.local') });

const dataSource = new DataSource({
    type: 'postgres',
    url: process.env.DATABASE_URL || 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
    synchronize: false,
    logging: false,
});

async function normalizeData() {
    try {
        await dataSource.initialize();
        console.log('✅ Conectado a la base de datos');
        console.log('🔄 Iniciando normalización...');

        // 1. NORMALIZAR GÉNEROS (LowerCase + Trim)
        // Debido a que TypeORM deserializa simple-array, lo mejor es hacerlo por SQL crudo para asegurar el array string
        // Pero 'songs' tiene 'genres' como TEXT (string separado por comas)
        // Vamos a buscar todas las canciones y actualizar una por una para estar seguros
        const songs = await dataSource.query('SELECT id, genres, title FROM songs');
        let genresUpdated = 0;

        for (const song of songs) {
            if (song.genres) {
                // Normalizar: lower, trim, unique
                const currentGenres = song.genres.split(',').map(g => g.trim().toLowerCase()).filter(g => g.length > 0);
                const uniqueGenres = [...new Set(currentGenres)];

                const newGenresStr = uniqueGenres.join(',');

                if (song.genres !== newGenresStr) {
                    await dataSource.query('UPDATE songs SET genres = $1 WHERE id = $2', [newGenresStr, song.id]);
                    genresUpdated++;
                }
            }
        }
        console.log(`✅ Géneros normalizados en ${genresUpdated} canciones.`);

        // 2. NORMALIZAR ARTISTAS (Trim)
        await dataSource.query("UPDATE artists SET stage_name = TRIM(stage_name)");
        console.log('✅ Nombres de artistas normalizados (TRIM).');

        // 3. FUSIÓN "MOTOR 24"
        console.log('🔍 Buscando duplicados de "MOTOR 24"...');
        const artists = await dataSource.query(`
      SELECT id, stage_name, (SELECT COUNT(*) FROM songs WHERE artist_id = artists.id) as song_count 
      FROM artists 
      WHERE LOWER(TRIM(stage_name)) = 'motor 24'
      ORDER BY song_count DESC
    `);

        if (artists.length > 1) {
            const winner = artists[0];
            const losers = artists.slice(1);

            console.log(`🏆 Artista principal: ${winner.stage_name} (ID: ${winner.id}) - ${winner.song_count} canciones`);

            for (const loser of losers) {
                console.log(`⚠️ Fusionando duplicado: ${loser.stage_name} (ID: ${loser.id}) - ${loser.song_count} canciones`);

                // Mover canciones
                await dataSource.query('UPDATE songs SET artist_id = $1 WHERE artist_id = $2', [winner.id, loser.id]);

                // Eliminar artista duplicado
                // Nota: Podría haber constraints, pero asumimos que solo 'songs' liga al artista por ahora o usamos CASCADE si está configurado
                // Si hay otras tablas referenciando, podría fallar. Vamos a intentar.
                try {
                    await dataSource.query('DELETE FROM artists WHERE id = $1', [loser.id]);
                    console.log(`✅ Duplicado eliminado: ${loser.id}`);
                } catch (e) {
                    console.error(`❌ No se pudo eliminar artista ${loser.id} (posibles referencias FK): ${e.message}`);
                }
            }
            console.log('✅ Fusión de MOTOR 24 completada.');
        } else {
            console.log('✅ No se encontraron duplicados de MOTOR 24.');
        }

        await dataSource.destroy();
        console.log('🏁 Proceso finalizado con éxito.');
        process.exit(0);

    } catch (error) {
        console.error('❌ Error fatal:', error);
        process.exit(1);
    }
}

normalizeData();
