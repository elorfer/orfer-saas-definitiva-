/**
 * 🎵 Script SIMPLE para crear 100 canciones de prueba
 * 
 * Usa conexión directa a PostgreSQL sin NestJS
 * 
 * Ejecutar: node scripts/seed-100-songs-simple.js
 */

const { Pool } = require('pg');

// URLs de audio gratuitas de SoundHelix
const SAMPLE_AUDIO_URLS = [
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3',
];

// Títulos de canciones
const SONG_PREFIXES = [
    'Midnight', 'Golden', 'Electric', 'Crystal', 'Neon', 'Velvet', 'Silver', 'Dark',
    'Cosmic', 'Ocean', 'Desert', 'Urban', 'Mystic', 'Eternal', 'Wild', 'Hidden',
    'Sacred', 'Frozen', 'Burning', 'Rising', 'Falling', 'Dancing', 'Flying', 'Silent',
    'Loud', 'Soft', 'Hard', 'Sweet', 'Bitter', 'Lost', 'Found', 'Broken', 'Perfect'
];

const SONG_SUFFIXES = [
    'Dreams', 'Nights', 'Vibes', 'Waves', 'Lights', 'Shadows', 'Echoes', 'Memories',
    'Roads', 'Skies', 'Stars', 'Hearts', 'Minds', 'Souls', 'Moments', 'Whispers',
    'Thunder', 'Rain', 'Fire', 'Ice', 'Wind', 'Earth', 'Love', 'Pain', 'Joy',
    'Hope', 'Fear', 'Pride', 'Glory', 'Power', 'Peace', 'War', 'Time', 'Space'
];

function generateRandomTitle() {
    const prefix = SONG_PREFIXES[Math.floor(Math.random() * SONG_PREFIXES.length)];
    const suffix = SONG_SUFFIXES[Math.floor(Math.random() * SONG_SUFFIXES.length)];
    return `${prefix} ${suffix}`;
}

function getRandomAudioUrl() {
    return SAMPLE_AUDIO_URLS[Math.floor(Math.random() * SAMPLE_AUDIO_URLS.length)];
}

function getRandomCoverUrl(index) {
    return `https://picsum.photos/seed/song${index}/400/400`;
}

function getRandomDuration() {
    return Math.floor(Math.random() * 240) + 120; // 2-6 minutos
}

function getRandomDate() {
    const year = 2020 + Math.floor(Math.random() * 5);
    const month = Math.floor(Math.random() * 12);
    const day = Math.floor(Math.random() * 28) + 1;
    return new Date(year, month, day).toISOString();
}

async function seed100Songs() {
    console.log('🎵 ════════════════════════════════════════════════════════');
    console.log('🎵 SCRIPT: Crear 100 canciones con audio de internet');
    console.log('🎵 ════════════════════════════════════════════════════════\n');

    const pool = new Pool({
        connectionString: process.env.DATABASE_URL || 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
    });

    try {
        // 1. Obtener artistas existentes
        console.log('🎤 Obteniendo artistas existentes...');
        const artistsResult = await pool.query('SELECT id, stage_name FROM artists');
        const artists = artistsResult.rows;

        if (artists.length === 0) {
            console.error('❌ No hay artistas. Crea al menos un artista primero.');
            return;
        }
        console.log(`   ✅ Encontrados ${artists.length} artistas\n`);

        // 2. Obtener géneros existentes
        console.log('🏷️  Obteniendo géneros existentes...');
        const genresResult = await pool.query('SELECT id, name FROM genres');
        const genres = genresResult.rows;

        if (genres.length === 0) {
            console.error('❌ No hay géneros. Crea al menos un género primero.');
            return;
        }
        console.log(`   ✅ Encontrados ${genres.length} géneros: ${genres.map(g => g.name).join(', ')}\n`);

        // 3. Crear 100 canciones
        console.log('🎵 Creando 100 canciones...\n');

        const usedTitles = new Set();
        let createdCount = 0;
        const genreCount = {};
        const artistCount = {};

        for (let i = 0; i < 100; i++) {
            // Generar título único
            let title = generateRandomTitle();
            let attempts = 0;
            while (usedTitles.has(title) && attempts < 100) {
                title = generateRandomTitle();
                attempts++;
            }
            usedTitles.add(title);

            // Seleccionar artista y género aleatorio
            const artist = artists[Math.floor(Math.random() * artists.length)];
            const genre = genres[Math.floor(Math.random() * genres.length)];

            const songData = {
                artist_id: artist.id,
                title: title,
                duration: getRandomDuration(),
                file_url: getRandomAudioUrl(),
                cover_art_url: getRandomCoverUrl(i),
                genres: genre.name, // simple-array format
                genre_id: genre.id,
                status: 'published',
                is_explicit: Math.random() > 0.8,
                is_featured: Math.random() > 0.7,
                release_date: getRandomDate(),
                total_streams: Math.floor(Math.random() * 500000) + 1000,
                total_likes: Math.floor(Math.random() * 10000) + 100,
                total_shares: Math.floor(Math.random() * 1000) + 10,
            };

            try {
                await pool.query(
                    `INSERT INTO songs (
            artist_id, title, duration, file_url, cover_art_url,
            genres, genre_id, status, is_explicit, is_featured,
            release_date, total_streams, total_likes, total_shares
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
                    [
                        songData.artist_id,
                        songData.title,
                        songData.duration,
                        songData.file_url,
                        songData.cover_art_url,
                        songData.genres,
                        songData.genre_id,
                        songData.status,
                        songData.is_explicit,
                        songData.is_featured,
                        songData.release_date,
                        songData.total_streams,
                        songData.total_likes,
                        songData.total_shares,
                    ]
                );

                createdCount++;
                genreCount[genre.name] = (genreCount[genre.name] || 0) + 1;
                artistCount[artist.stage_name] = (artistCount[artist.stage_name] || 0) + 1;

                if ((i + 1) % 10 === 0) {
                    console.log(`   📊 Progreso: ${i + 1}/100 canciones creadas...`);
                }
            } catch (error) {
                console.error(`   ❌ Error creando "${title}": ${error.message}`);
            }
        }

        // 4. Resumen final
        console.log('\n🎉 ════════════════════════════════════════════════════════');
        console.log('🎉 SEEDING COMPLETADO');
        console.log('🎉 ════════════════════════════════════════════════════════\n');
        console.log(`   📀 Canciones creadas: ${createdCount}`);

        console.log('\n   📊 Distribución por género:');
        for (const [name, count] of Object.entries(genreCount)) {
            console.log(`      - ${name}: ${count} canciones`);
        }

        console.log('\n   👤 Distribución por artista:');
        for (const [name, count] of Object.entries(artistCount)) {
            console.log(`      - ${name}: ${count} canciones`);
        }

        console.log('\n✅ ¡Listo! Ahora tienes 100 canciones con audio real de internet.\n');

    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        await pool.end();
    }
}

seed100Songs();
