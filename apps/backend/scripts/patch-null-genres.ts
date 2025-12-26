import { DataSource } from 'typeorm';
import { dataSourceOptions } from '../src/database/data-source';

async function patchNullGenres() {
    console.log('🚀 Iniciando parche de géneros nulos...');

    const dataSource = new DataSource(dataSourceOptions);

    try {
        await dataSource.initialize();
        console.log('✅ Base de datos conectada.');

        // Ejecutar query directa para máxima eficiencia
        // Postgres usa JSONB para arrays, así que el formato '["MIX"]' es correcto
        // Alternativamente podría ser necesaria conversión jsonb, pero string literal suele funcionar si el driver lo maneja
        const result = await dataSource.query(
            `UPDATE "songs" SET "genres" = '["MIX"]' WHERE "genres" IS NULL`
        );

        // En algunos drivers result[1] es el rowCount
        const updatedCount = result[1] ?? 'desconocido';

        console.log(`✨ ÉXITO: Se actualizaron ${updatedCount} canciones.`);
        console.log('🎸 Ahora todas tienen al menos el género ["MIX"].');

    } catch (error) {
        console.error('❌ Error ejecutando el parche:', error);
    } finally {
        if (dataSource.isInitialized) {
            await dataSource.destroy();
            console.log('👋 Conexión cerrada.');
        }
    }
}

patchNullGenres();
