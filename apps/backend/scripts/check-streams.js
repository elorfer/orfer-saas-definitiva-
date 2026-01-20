const { Pool } = require('pg');

async function checkStreams() {
    const pool = new Pool({
        connectionString: 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
    });

    try {
        const countResult = await pool.query('SELECT COUNT(*) as total FROM streams');
        console.log('Total streams:', countResult.rows[0].total);

        const recentResult = await pool.query(
            'SELECT s.id, s.song_id, s.created_at FROM streams s ORDER BY s.created_at DESC LIMIT 15'
        );

        console.log('\nÚltimos streams:');
        recentResult.rows.forEach((r, i) => {
            console.log(`${i + 1}. ${r.created_at.toISOString()} - Song: ${r.song_id.substring(0, 8)}...`);
        });

        // Calcular diferencias de tiempo entre streams consecutivos
        if (recentResult.rows.length > 1) {
            console.log('\nDiferencias de tiempo entre streams:');
            for (let i = 0; i < recentResult.rows.length - 1; i++) {
                const diff = (new Date(recentResult.rows[i].created_at) - new Date(recentResult.rows[i + 1].created_at)) / 1000;
                console.log(`  Entre ${i + 1} y ${i + 2}: ${diff.toFixed(0)} segundos`);
            }
        }
    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await pool.end();
    }
}

checkStreams();
