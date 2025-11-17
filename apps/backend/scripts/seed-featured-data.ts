import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../src/common/entities/user.entity';
import { Artist } from '../src/common/entities/artist.entity';
import { Song } from '../src/common/entities/song.entity';
import { Playlist } from '../src/common/entities/playlist.entity';
import * as bcrypt from 'bcrypt';

async function seedFeaturedData() {
  console.log('🌱 Iniciando seeding de datos destacados...');
  
  const app = await NestFactory.createApplicationContext(AppModule);
  
  const userRepo = app.get<Repository<User>>(getRepositoryToken(User));
  const artistRepo = app.get<Repository<Artist>>(getRepositoryToken(Artist));
  const songRepo = app.get<Repository<Song>>(getRepositoryToken(Song));
  const playlistRepo = app.get<Repository<Playlist>>(getRepositoryToken(Playlist));

  try {
    // Crear algunos usuarios artistas de prueba
    console.log('👤 Creando usuarios artistas...');
    
    const artistUsers = [
      {
        email: 'john.vintage@example.com',
        username: 'johnvintage',
        firstName: 'John',
        lastName: 'Vintage',
        password: 'password123',
        role: 'artist' as any,
      },
      {
        email: 'sarah.retro@example.com',
        username: 'sarahretro',
        firstName: 'Sarah',
        lastName: 'Retro',
        password: 'password123',
        role: 'artist' as any,
      },
      {
        email: 'mike.classic@example.com',
        username: 'mikeclassic',
        firstName: 'Mike',
        lastName: 'Classic',
        password: 'password123',
        role: 'artist' as any,
      },
      {
        email: 'luna.blues@example.com',
        username: 'lunablues',
        firstName: 'Luna',
        lastName: 'Blues',
        password: 'password123',
        role: 'artist' as any,
      },
      {
        email: 'jazz.master@example.com',
        username: 'jazzmaster',
        firstName: 'Jazz',
        lastName: 'Master',
        password: 'password123',
        role: 'artist' as any,
      },
      {
        email: 'rock.legend@example.com',
        username: 'rocklegend',
        firstName: 'Rock',
        lastName: 'Legend',
        password: 'password123',
        role: 'artist' as any,
      },
    ];

    const createdArtists = [];
    for (const userData of artistUsers) {
      try {
        // Verificar si el usuario ya existe
        let existingUser = await userRepo.findOne({ where: { email: userData.email } });
        if (!existingUser) {
          existingUser = await userRepo.findOne({ where: { username: userData.username } });
        }
        
        if (existingUser) {
          console.log(`⚠️ Usuario ${userData.username} ya existe, obteniendo artista...`);
          const existingArtist = await artistRepo.findOne({ where: { userId: existingUser.id } });
          if (existingArtist) {
            createdArtists.push(existingArtist);
          }
          continue;
        }

        // Crear usuario
        const hashedPassword = await bcrypt.hash(userData.password, 10);
        const user = userRepo.create({
          ...userData,
          passwordHash: hashedPassword,
        });
        await userRepo.save(user);
        
        // Crear perfil de artista
        const artist = artistRepo.create({
          userId: user.id,
          stageName: `${userData.firstName} ${userData.lastName}`,
          bio: `Artista vintage especializado en ${userData.firstName === 'John' ? 'blues' : userData.firstName === 'Sarah' ? 'jazz' : userData.firstName === 'Luna' ? 'blues' : userData.firstName === 'Jazz' ? 'jazz' : 'rock'} clásico`,
          websiteUrl: `https://${userData.username}.com`,
          socialLinks: {
            instagram: `@${userData.username}`,
            twitter: `@${userData.username}`,
          },
          verificationStatus: Math.random() > 0.5,
          totalStreams: Math.floor(Math.random() * 2000000) + 50000, // Más streams para aparecer en top
          totalFollowers: Math.floor(Math.random() * 100000) + 5000, // Más seguidores
          monthlyListeners: Math.floor(Math.random() * 50000) + 1000,
        });
        await artistRepo.save(artist);
        
        createdArtists.push(artist);
        console.log(`✅ Artista creado: ${artist.stageName} - ${artist.totalFollowers} seguidores`);
      } catch (error) {
        console.log(`❌ Error creando usuario ${userData.username}:`, error.message);
      }
    }

    // Obtener artistas existentes si no se crearon nuevos
    if (createdArtists.length === 0) {
      console.log('🔍 Obteniendo artistas existentes...');
      const existingArtists = await artistRepo.find({ take: 6 });
      createdArtists.push(...existingArtists);
      console.log(`✅ Encontrados ${existingArtists.length} artistas existentes`);
    }

    // Crear más canciones de prueba
    console.log('🎵 Creando canciones destacadas...');
    
    const songTemplates = [
      { title: 'Midnight Blues', genre: 'blues' },
      { title: 'Vintage Dreams', genre: 'jazz' },
      { title: 'Retro Waves', genre: 'rock' },
      { title: 'Classic Memories', genre: 'blues' },
      { title: 'Golden Era', genre: 'jazz' },
      { title: 'Old School Vibes', genre: 'rock' },
      { title: 'Soulful Journey', genre: 'blues' },
      { title: 'Jazz Night', genre: 'jazz' },
      { title: 'Rock Anthem', genre: 'rock' },
      { title: 'Blues Ballad', genre: 'blues' },
      { title: 'Smooth Jazz', genre: 'jazz' },
      { title: 'Vintage Rock', genre: 'rock' },
    ];

    const createdSongs = [];
    for (let i = 0; i < songTemplates.length; i++) {
      const template = songTemplates[i];
      const artist = createdArtists[i % createdArtists.length];
      
      if (!artist) continue;
      
      try {
        // Verificar si la canción ya existe
        const existingSong = await songRepo.findOne({ 
          where: { 
            title: template.title,
            artistId: artist.id 
          } 
        });
        
        if (existingSong) {
          console.log(`⚠️ Canción ${template.title} ya existe, saltando...`);
          // Actualizar streams para que aparezca en top
          existingSong.totalStreams = Math.floor(Math.random() * 1000000) + 100000;
          await songRepo.save(existingSong);
          createdSongs.push(existingSong);
          continue;
        }

        const song = songRepo.create({
          artistId: artist.id,
          title: template.title,
          duration: Math.floor(Math.random() * 300) + 120, // 2-7 minutos
          fileUrl: `https://example.com/songs/${template.title.toLowerCase().replace(/\s+/g, '-')}.m3u8`,
          coverArtUrl: `https://picsum.photos/300/300?random=${i + 100}`,
          lyrics: `Letra de ${template.title}...`,
          genreId: null,
          trackNumber: i + 1,
          status: 'published' as any,
          isExplicit: false,
          releaseDate: new Date(2020 + Math.floor(Math.random() * 4), Math.floor(Math.random() * 12), Math.floor(Math.random() * 28)),
          totalStreams: Math.floor(Math.random() * 1000000) + 100000, // Más streams para aparecer en top
          totalLikes: Math.floor(Math.random() * 50000) + 1000,
          totalShares: Math.floor(Math.random() * 5000) + 100,
        });
        await songRepo.save(song);
        createdSongs.push(song);
        
        console.log(`✅ Canción creada: ${song.title} por ${artist.stageName} - ${song.totalStreams} streams`);
      } catch (error) {
        console.log(`❌ Error creando canción: ${error.message}`);
      }
    }

    // Crear más playlists destacadas
    console.log('📋 Creando playlists destacadas...');
    
    const playlistTemplates = [
      { name: 'Vintage Hits Collection', description: 'Las mejores canciones vintage de todos los tiempos' },
      { name: 'Blues Masters', description: 'Los maestros del blues clásico' },
      { name: 'Jazz Classics', description: 'Jazz atemporal para los verdaderos amantes' },
      { name: 'Rock Legends', description: 'Las leyendas del rock vintage' },
      { name: 'Soulful Moments', description: 'Momentos de alma y blues profundo' },
      { name: 'Jazz Lounge', description: 'Ambiente relajante con lo mejor del jazz' },
      { name: 'Rock Revolution', description: 'Los temas que definieron una generación' },
      { name: 'Blues I', description: 'Una selección exclusiva de blues' },
    ];

    // Obtener un usuario para crear las playlists
    let playlistCreator = null;
    if (createdArtists.length > 0) {
      const firstArtist = createdArtists[0];
      playlistCreator = await userRepo.findOne({ where: { id: firstArtist.userId } });
    }
    
    // Si no hay artista, obtener cualquier usuario o crear uno
    if (!playlistCreator) {
      playlistCreator = await userRepo.findOne({ where: {} });
      if (!playlistCreator) {
        console.log('⚠️ No hay usuarios, creando usuario temporal...');
        const hashedPassword = await bcrypt.hash('password123', 10);
        playlistCreator = userRepo.create({
          email: 'playlist.creator@example.com',
          username: 'playlistcreator',
          firstName: 'Playlist',
          lastName: 'Creator',
          passwordHash: hashedPassword,
          role: 'user' as any,
        });
        await userRepo.save(playlistCreator);
      }
    }

    const createdPlaylists = [];
    for (let i = 0; i < playlistTemplates.length; i++) {
      const template = playlistTemplates[i];
      
      if (!playlistCreator) continue;
      
      try {
        // Verificar si la playlist ya existe
        const existingPlaylist = await playlistRepo.findOne({ 
          where: { 
            name: template.name,
            userId: playlistCreator.id 
          } 
        });
        
        if (existingPlaylist) {
          console.log(`⚠️ Playlist ${template.name} ya existe, actualizando a destacada...`);
          existingPlaylist.isFeatured = true;
          existingPlaylist.visibility = 'public' as any;
          await playlistRepo.save(existingPlaylist);
          createdPlaylists.push(existingPlaylist);
          continue;
        }

        const playlist = playlistRepo.create({
          userId: playlistCreator.id,
          name: template.name,
          description: template.description,
          coverArtUrl: `https://picsum.photos/400/400?random=${i + 200}`,
          visibility: 'public' as any,
          totalTracks: Math.floor(Math.random() * 25) + 10,
          totalDuration: Math.floor(Math.random() * 5400) + 1800, // 30min - 2.5h
          isFeatured: true, // Marcar como destacada
        });
        await playlistRepo.save(playlist);
        createdPlaylists.push(playlist);
        
        console.log(`✅ Playlist creada: ${playlist.name}`);
      } catch (error) {
        console.log(`❌ Error creando playlist: ${error.message}`);
      }
    }

    // Actualizar estadísticas de artistas existentes si tienen pocos streams/seguidores
    console.log('📊 Actualizando estadísticas de artistas...');
    const allArtists = await artistRepo.find();
    for (const artist of allArtists) {
      if (artist.totalStreams < 50000 || artist.totalFollowers < 1000) {
        artist.totalStreams = Math.floor(Math.random() * 2000000) + 50000;
        artist.totalFollowers = Math.floor(Math.random() * 100000) + 5000;
        artist.monthlyListeners = Math.floor(Math.random() * 50000) + 1000;
        await artistRepo.save(artist);
        console.log(`✅ Artista ${artist.stageName} actualizado - ${artist.totalFollowers} seguidores`);
      }
    }

    // Actualizar estadísticas de canciones existentes si tienen pocos streams
    console.log('📊 Actualizando estadísticas de canciones...');
    const allSongs = await songRepo.find();
    for (const song of allSongs) {
      if (song.totalStreams < 100000) {
        song.totalStreams = Math.floor(Math.random() * 1000000) + 100000;
        song.totalLikes = Math.floor(Math.random() * 50000) + 1000;
        await songRepo.save(song);
        console.log(`✅ Canción ${song.title} actualizada - ${song.totalStreams} streams`);
      }
    }

    console.log('🎉 Seeding completado exitosamente!');
    console.log(`📊 Resumen:`);
    console.log(`   - Artistas: ${createdArtists.length}`);
    console.log(`   - Canciones: ${createdSongs.length}`);
    console.log(`   - Playlists destacadas: ${createdPlaylists.length}`);
    
  } catch (error) {
    console.error('❌ Error durante el seeding:', error);
  } finally {
    await app.close();
  }
}

seedFeaturedData();
