const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

async function restoreSongs() {
    // Conexión a la base de datos
    const client = new Client({
        host: 'localhost',
        port: 5432,
        user: 'vintage_user',
        password: 'vintage_password_2024',
        database: 'vintage_music',
    });

    try {
        await client.connect();
        console.log('🔗 Conectado a la base de datos');

        // Obtener el artista "Struky Music Collection"
        const artistResult = await client.query(
            `SELECT a.id FROM artists a
       JOIN users u ON a.user_id = u.id
       WHERE u.email = 'struky.music@struky.com'
       LIMIT 1`
        );

        if (artistResult.rows.length === 0) {
            console.error('❌ No se encontró el artista. Ejecuta primero create-restore-artist.sql');
            return;
        }

        const artistId = artistResult.rows[0].id;
        console.log(`✅ Artista encontrado: ${artistId}`);

        // Leer archivos MP3
        const uploadsDir = path.join(__dirname, '../uploads/songs');
        const coversDir = path.join(__dirname, '../uploads/covers');

        if (!fs.existsSync(uploadsDir)) {
            console.error('❌ No se encontró la carpeta uploads/songs');
            return;
        }

        const mp3Files = fs.readdirSync(uploadsDir).filter(f => f.endsWith('.mp3'));
        console.log(`📁 Encontrados ${mp3Files.length} archivos MP3`);

        const coverFiles = fs.existsSync(coversDir)
            ? fs.readdirSync(coversDir).filter(f => /\.(jpg|jpeg|png|webp)$/.test(f))
            : [];
        console.log(`🖼️  Encontradas ${coverFiles.length} portadas`);

        let restored = 0;
        let skipped = 0;

        for (let i = 0; i < mp3Files.length; i++) {
            const mp3File = mp3Files[i];
            const fileId = mp3File.replace('.mp3', '');
            const fileUrl = `/uploads/songs/${mp3File}`;

            try {
                // Verificar si ya existe
                const existingResult = await client.query(
                    'SELECT id FROM songs WHERE file_url = $1',
                    [fileUrl]
                );

                if (existingResult.rows.length > 0) {
                    skipped++;
                    continue;
                }

                // Buscar portada
                const matchingCover = coverFiles.find(c => c.startsWith(fileId.substring(0, 8)));
                const coverUrl = matchingCover ? `/uploads/covers/${matchingCover}` : null;

                // Obtener tamaño para estimar duración
                const filePath = path.join(uploadsDir, mp3File);
                const stats = fs.statSync(filePath);
                const fileSizeInMB = stats.size / (1024 * 1024);
                const estimatedDuration = Math.floor(fileSizeInMB * 60); // 1MB ≈ 1 min

                const title = `Canción ${(i + 1).toString().padStart(3, '0')}`;

                // Insertar canción
                await client.query(`
          INSERT INTO songs (
            id, artist_id, title, duration, file_url, cover_art_url,
            status, is_explicit, release_date,
            total_streams, total_likes, total_shares,
            created_at, updated_at
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW())
        `, [
                    require('crypto').randomUUID(),
                    artistId,
                    title,
                    estimatedDuration,
                    fileUrl,
                    coverUrl,
                    'published',
                    false,
                    new Date(),
                    Math.floor(Math.random() * 50000) + 1000,
                    Math.floor(Math.random() * 5000) + 100,
                    Math.floor(Math.random() * 500) + 10,
                ]);

                restored++;

                if (restored % 10 === 0) {
                    console.log(`✅ Restauradas ${restored}/${mp3Files.length}...`);
                }
            } catch (error) {
                console.error(`❌ Error con ${mp3File}:`, error.message);
            }
        }

        console.log('\n🎉 Restaur ación completada!');
        console.log(`📊 Canciones restauradas: ${restored}`);
        console.log(`⏭️  Canciones omitidas (ya existían): ${skipped}`);
        console.log(`📁 Total procesado: ${mp3Files.length}`);
        console.log('\n💡 Puedes editar los títulos desde el panel admin');

    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        await client.end();
    }
}

restoreSongs();
