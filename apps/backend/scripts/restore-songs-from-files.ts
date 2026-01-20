import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../src/common/entities/user.entity';
import { Artist } from '../src/common/entities/artist.entity';
import { Song } from '../src/common/entities/song.entity';
import * as fs from 'fs';
import * as path from 'path';
import * as bcrypt from 'bcrypt';

async function restoreSongsFromFiles() {
    console.log('🔄 Restaurando canciones desde archivos locales...');

    const app = await NestFactory.createApplicationContext(AppModule);

    const userRepo = app.get<Repository<User>>(getRepositoryToken(User));
    const artistRepo = app.get<Repository<Artist>>(getRepositoryToken(Artist));
    const songRepo = app.get<Repository<Song>>(getRepositoryToken(Song));

    try {
        // 1. Crear o obtener un artista por defecto
        console.log('👤 Creando artista por defecto...');

        let defaultArtistUser = await userRepo.findOne({ where: { email: 'default.artist@struky.com' } });

        if (!defaultArtistUser) {
            const hashedPassword = await bcrypt.hash('artist123', 10);
            defaultArtistUser = userRepo.create({
                email: 'default.artist@struky.com',
                username: 'defaultartist',
                firstName: 'Struky',
                lastName: 'Music',
                passwordHash: hashedPassword,
                role: 'artist' as any,
                isVerified: true,
                isActive: true,
            });
            await userRepo.save(defaultArtistUser);
            console.log('✅ Usuario artista creado');
        }

        let defaultArtist = await artistRepo.findOne({ where: { userId: defaultArtistUser.id } });

        if (!defaultArtist) {
            defaultArtist = artistRepo.create({
                userId: defaultArtistUser.id,
                stageName: 'Struky Music Collection',
                bio: 'Colección de música restaurada',
                verificationStatus: true,
                totalStreams: 100000,
                totalFollowers: 5000,
                monthlyListeners: 1000,
            });
            await artistRepo.save(defaultArtist);
            console.log('✅ Artista creado');
        }

        // 2. Leer todos los archivos MP3
        const uploadsDir = path.join(__dirname, '../../uploads/songs');
        const coversDir = path.join(__dirname, '../../uploads/covers');

        if (!fs.existsSync(uploadsDir)) {
            console.error('❌ No se encontró la carpeta de uploads');
            return;
        }

        const mp3Files = fs.readdirSync(uploadsDir).filter(file => file.endsWith('.mp3'));
        console.log(`📁 Encontrados ${mp3Files.length} archivos MP3`);

        const coverFiles = fs.existsSync(coversDir)
            ? fs.readdirSync(coversDir).filter(f => /\.(jpg|jpeg|png|webp)$/.test(f))
            : [];
        console.log(`🖼️  Encontradas ${coverFiles.length} portadas`);

        // 3. Crear canciones
        let restored = 0;
        for (let i = 0; i < mp3Files.length; i++) {
            const mp3File = mp3Files[i];
            const fileId = mp3File.replace('.mp3', '');

            try {
                // Verificar si ya existe
                const existing = await songRepo.findOne({ where: { fileUrl: `/uploads/songs/${mp3File}` } });
                if (existing) {
                    console.log(`⏭️  Canción ya existe: ${existing.title}`);
                    continue;
                }

                // Buscar portada correspondiente (mismo UUID base)
                let coverUrl = null;
                const matchingCover = coverFiles.find(cover => cover.startsWith(fileId.substring(0, 8)));
                if (matchingCover) {
                    coverUrl = `/uploads/covers/${matchingCover}`;
                }

                // Generar título basado en el índice
                const title = `Canción Restaurada ${i + 1}`;

                // Obtener tamaño del archivo para estimar duración
                const filePath = path.join(uploadsDir, mp3File);
                const stats = fs.statSync(filePath);
                const fileSizeInMB = stats.size / (1024 * 1024);
                // Estimación: 1MB ≈ 1 minuto a 128kbps
                const estimatedDuration = Math.floor(fileSizeInMB * 60);

                const song = songRepo.create({
                    artistId: defaultArtist.id,
                    title,
                    duration: estimatedDuration,
                    fileUrl: `/uploads/songs/${mp3File}`,
                    coverArtUrl: coverUrl,
                    status: 'published' as any,
                    isExplicit: false,
                    releaseDate: new Date(),
                    totalStreams: Math.floor(Math.random() * 50000) + 1000,
                    totalLikes: Math.floor(Math.random() * 5000) + 100,
                    totalShares: Math.floor(Math.random() * 500) + 10,
                });

                await songRepo.save(song);
                restored++;

                if (restored % 10 === 0) {
                    console.log(`✅ Restauradas ${restored}/${mp3Files.length} canciones...`);
                }
            } catch (error) {
                console.error(`❌ Error restaurando ${mp3File}:`, error.message);
            }
        }

        console.log('\n🎉 Restauración completada!');
        console.log(`📊 Canciones restauradas: ${restored}/${mp3Files.length}`);
        console.log(`👤 Artista: ${defaultArtist.stageName}`);
        console.log('\n💡 Ahora puedes editar los títulos y detalles desde el panel admin');

    } catch (error) {
        console.error('❌ Error durante la restauración:', error);
    } finally {
        await app.close();
    }
}

restoreSongsFromFiles();
