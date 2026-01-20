const { Pool } = require('pg');

async function deleteSongs() {
    const pool = new Pool({
        connectionString: 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
    });

    try {
        // Eliminar todas las canciones con URL de SoundHelix
        const result = await pool.query(
            "DELETE FROM songs WHERE file_url LIKE '%soundhelix%'"
        );
        console.log('🗑️ Canciones de SoundHelix eliminadas:', result.rowCount);
    } catch (error) {
        console.error('❌ Error:', error.message);
    } finally {
        await pool.end();
    }
}

deleteSongs();
