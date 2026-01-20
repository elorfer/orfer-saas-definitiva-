/**
 * 🎵 Script para crear 100 canciones de prueba con audio real de internet
 * 
 * Usa URLs de audio gratuitas de:
 * - Free Music Archive (freemusicarchive.org)
 * - SoundHelix (samples de prueba)
 * - Archive.org (dominio público)
 * 
 * Ejecutar: npx ts-node scripts/seed-100-songs.ts
 */

import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Artist } from '../src/common/entities/artist.entity';
import { Song, SongStatus } from '../src/common/entities/song.entity';
import { Genre } from '../src/common/entities/genre.entity';

// URLs de audio gratuitas de SoundHelix (samples de música electrónica/ambient)
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

// Títulos de canciones generados aleatoriamente
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

function generateRandomTitle(): string {
    const prefix = SONG_PREFIXES[Math.floor(Math.random() * SONG_PREFIXES.length)];
    const suffix = SONG_SUFFIXES[Math.floor(Math.random() * SONG_SUFFIXES.length)];
    return `${prefix} ${suffix}`;
}

function getRandomAudioUrl(): string {
    return SAMPLE_AUDIO_URLS[Math.floor(Math.random() * SAMPLE_AUDIO_URLS.length)];
}

function getRandomCoverUrl(index: number): string {
    // Usar Picsum para imágenes aleatorias
    return `https://picsum.photos/seed/song${index}/400/400`;
}

function getRandomDuration(): number {
    // Entre 2 y 6 minutos (en segundos)
    return Math.floor(Math.random() * 240) + 120;
}

async function seed100Songs() {
    console.log('🎵 ════════════════════════════════════════════════════════');
    console.log('🎵 SCRIPT: Crear 100 canciones con audio de internet');
    console.log('🎵 ════════════════════════════════════════════════════════\n');

    const app = await NestFactory.createApplicationContext(AppModule);

    const artistRepo = app.get<Repository<Artist>>(getRepositoryToken(Artist));
    const songRepo = app.get<Repository<Song>>(getRepositoryToken(Song));
    const genreRepo = app.get<Repository<Genre>>(getRepositoryToken(Genre));

    try {
        // 1. Obtener todos los artistas existentes
        console.log('🎤 Obteniendo artistas existentes...');
        const artists = await artistRepo.find();

        if (artists.length === 0) {
            console.error('❌ No hay artistas en la base de datos. Crea al menos un artista primero.');
            await app.close();
            return;
        }
        console.log(`   ✅ Encontrados ${artists.length} artistas\n`);

        // 2. Obtener todos los géneros existentes
        console.log('🏷️  Obteniendo géneros existentes...');
        const genres = await genreRepo.find();

        if (genres.length === 0) {
            console.error('❌ No hay géneros en la base de datos. Crea al menos un género primero.');
            await app.close();
            return;
        }
        console.log(`   ✅ Encontrados ${genres.length} géneros: ${genres.map(g => g.name).join(', ')}\n`);

        // 3. Crear 100 canciones
        console.log('🎵 Creando 100 canciones...\n');

        const createdSongs: Song[] = [];
        const usedTitles = new Set<string>();

        for (let i = 0; i < 100; i++) {
            // Generar título único
            let title = generateRandomTitle();
            let attempts = 0;
            while (usedTitles.has(title) && attempts < 100) {
                title = generateRandomTitle();
                attempts++;
            }
            usedTitles.add(title);

            // Seleccionar artista aleatorio
            const artist = artists[Math.floor(Math.random() * artists.length)];

            // Seleccionar género aleatorio
            const genre = genres[Math.floor(Math.random() * genres.length)];

            // Crear la canción
            const song = songRepo.create({
                artistId: artist.id,
                title: title,
                duration: getRandomDuration(),
                fileUrl: getRandomAudioUrl(),
                coverArtUrl: getRandomCoverUrl(i),
                genres: [genre.name], // Asignar el género como array
                genreId: genre.id,
                status: SongStatus.PUBLISHED,
                isExplicit: Math.random() > 0.8, // 20% explícitas
                isFeatured: Math.random() > 0.7, // 30% destacadas
                releaseDate: new Date(
                    2020 + Math.floor(Math.random() * 5), // 2020-2024
                    Math.floor(Math.random() * 12),
                    Math.floor(Math.random() * 28) + 1
                ),
                totalStreams: Math.floor(Math.random() * 500000) + 1000,
                totalLikes: Math.floor(Math.random() * 10000) + 100,
                totalShares: Math.floor(Math.random() * 1000) + 10,
            });

            try {
                await songRepo.save(song);
                createdSongs.push(song);

                // Mostrar progreso cada 10 canciones
                if ((i + 1) % 10 === 0) {
                    console.log(`   📊 Progreso: ${i + 1}/100 canciones creadas...`);
                }
            } catch (error: any) {
                console.error(`   ❌ Error creando canción "${title}": ${error.message}`);
            }
        }

        // 4. Resumen final
        console.log('\n🎉 ════════════════════════════════════════════════════════');
        console.log('🎉 SEEDING COMPLETADO');
        console.log('🎉 ════════════════════════════════════════════════════════\n');
        console.log(`   📀 Canciones creadas: ${createdSongs.length}`);
        console.log(`   🎤 Artistas usados: ${artists.length}`);
        console.log(`   🏷️  Géneros usados: ${genres.length}`);

        // Estadísticas por género
        console.log('\n   📊 Distribución por género:');
        const genreCount: Record<string, number> = {};
        for (const song of createdSongs) {
            const genreName = song.genres?.[0] || 'Sin género';
            genreCount[genreName] = (genreCount[genreName] || 0) + 1;
        }
        for (const [name, count] of Object.entries(genreCount)) {
            console.log(`      - ${name}: ${count} canciones`);
        }

        // Estadísticas por artista
        console.log('\n   👤 Distribución por artista:');
        const artistCount: Record<string, number> = {};
        for (const song of createdSongs) {
            const artist = artists.find(a => a.id === song.artistId);
            const artistName = artist?.stageName || 'Desconocido';
            artistCount[artistName] = (artistCount[artistName] || 0) + 1;
        }
        for (const [name, count] of Object.entries(artistCount)) {
            console.log(`      - ${name}: ${count} canciones`);
        }

        console.log('\n✅ ¡Listo! Ahora tienes 100 canciones con audio real.\n');

    } catch (error) {
        console.error('❌ Error durante el seeding:', error);
    } finally {
        await app.close();
    }
}

// Ejecutar
seed100Songs();
