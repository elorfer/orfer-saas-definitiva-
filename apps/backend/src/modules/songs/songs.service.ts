import { Injectable, NotFoundException, ForbiddenException, BadRequestException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository, Not } from 'typeorm';
import * as fs from 'fs';
import * as path from 'path';

import { Song, SongStatus } from '../../common/entities/song.entity';
import { Artist } from '../../common/entities/artist.entity';
import { Album } from '../../common/entities/album.entity';
import { Genre } from '../../common/entities/genre.entity';
import { LocalStorageService } from './local-storage.service';
import { CoversStorageService } from '../covers/covers-storage.service';
import { AudioMetadataService } from '../../common/services/audio-metadata.service';
import { SongMapper } from './mappers/song.mapper';
import { SongResponseDto, PaginatedSongsResponseDto, HomeFeedResponseDto } from './dto/song-response.dto';

@Injectable()
export class SongsService {
  private readonly logger = new Logger(SongsService.name);

  constructor(
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
    @InjectRepository(Artist)
    private readonly artistRepository: Repository<Artist>,
    @InjectRepository(Album)
    private readonly albumRepository: Repository<Album>,
    @InjectRepository(Genre)
    private readonly genreRepository: Repository<Genre>,
    private readonly localStorageService: LocalStorageService,
    private readonly coversStorageService: CoversStorageService,
    private readonly dataSource: DataSource,
    private readonly audioMetadataService: AudioMetadataService,
  ) {}

  async findAll(page: number = 1, limit: number = 10, includeAllStatuses: boolean = false): Promise<{ songs: Song[]; total: number }> {
    const whereCondition = includeAllStatuses ? {} : { status: SongStatus.PUBLISHED };
    
    const [songs, total] = await this.songRepository.findAndCount({
      where: whereCondition,
      relations: ['artist', 'album', 'genre'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return { songs, total };
  }

  async findOne(id: string): Promise<Song> {
    const song = await this.songRepository.findOne({
      where: { id },
      relations: ['artist', 'album', 'genre'],
    });

    if (!song) {
      throw new NotFoundException('Canción no encontrada');
    }

    return song;
  }

  async findByArtist(artistId: string, page: number = 1, limit: number = 10): Promise<{ songs: Song[]; total: number }> {
    const [songs, total] = await this.songRepository.findAndCount({
      where: { artistId, status: SongStatus.PUBLISHED },
      relations: ['album', 'genre'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return { songs, total };
  }

  // ⚡ OPTIMIZADO: Obtener canciones top con query optimizada
  async getTopSongs(limit: number = 10): Promise<Song[]> {
    // ⚡ OPTIMIZACIÓN: Usar QueryBuilder para mejor rendimiento y control
    // Solo cargar relaciones necesarias y limitar datos
    return this.songRepository
      .createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('artist.user', 'user') // Solo para datos básicos del artista
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .orderBy('song.totalStreams', 'DESC')
      .addOrderBy('song.createdAt', 'DESC') // Orden secundario para consistencia
      .take(limit)
      .getMany();
  }

  async getSongsByGenre(genreId: string, page: number = 1, limit: number = 10): Promise<{ songs: SongResponseDto[]; total: number }> {
    // Obtener el género para obtener su nombre
    const genre = await this.genreRepository.findOne({
      where: { id: genreId },
    });

    if (!genre) {
      return { songs: [], total: 0 };
    }

    // Normalizar el nombre del género para búsqueda (minúsculas, sin espacios extra)
    const normalizedGenreName = genre.name.toLowerCase().trim();

    // Buscar canciones que tengan:
    // 1. genreId igual al ID del género, O
    // 2. El nombre del género en el array genres
    const queryBuilder = this.songRepository
      .createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('song.album', 'album')
      .leftJoinAndSelect('song.genre', 'genre')
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere(
        '(song.genreId = :genreId OR LOWER(song.genres) LIKE :genreName)',
        {
          genreId,
          genreName: `%${normalizedGenreName}%`,
        }
      )
      .orderBy('song.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);

    const [songs, total] = await queryBuilder.getManyAndCount();

    // Convertir a DTOs usando el mapper
    return {
      songs: SongMapper.toDtoArray(songs),
      total,
    };
  }

  async searchSongs(query: string, page: number = 1, limit: number = 10): Promise<{ songs: Song[]; total: number }> {
    const searchQuery = `%${query}%`;
    const [songs, total] = await this.songRepository
      .createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('song.album', 'album')
      .leftJoinAndSelect('song.genre', 'genre')
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere(
        '(song.title ILIKE :query OR artist.stageName ILIKE :query OR COALESCE(song.genres, \'\')::text ILIKE :query)',
        { query: searchQuery }
      )
      .skip((page - 1) * limit)
      .take(limit)
      .orderBy('song.createdAt', 'DESC')
      .getManyAndCount();

    return { songs, total };
  }

  async incrementStreams(songId: string): Promise<void> {
    await this.songRepository.increment({ id: songId }, 'totalStreams', 1);
  }

  async likeSong(songId: string, userId: string): Promise<void> {
    // Implementar lógica de likes
    await this.songRepository.increment({ id: songId }, 'totalLikes', 1);
  }

  async unlikeSong(songId: string, userId: string): Promise<void> {
    // Implementar lógica de unlikes
    await this.songRepository.decrement({ id: songId }, 'totalLikes', 1);
  }

  /**
   * Sube un archivo de audio y opcionalmente una imagen de portada
   * @param audioFile Archivo de audio
   * @param coverFile Archivo de imagen (opcional)
   * @param userId ID del usuario que sube el archivo
   * @returns URLs de los archivos subidos
   * @deprecated Usar uploadAndCreateSong para transaccionalidad
   */
  async uploadSongWithCover(
    audioFile: Express.Multer.File,
    coverFile: Express.Multer.File | undefined,
    userId?: string,
  ): Promise<{ audio: { url: string; fileName: string }; cover?: { url: string; fileName: string } }> {
    if (!audioFile) {
      throw new BadRequestException('No se proporcionó archivo de audio');
    }

    try {
      // Subir archivo de audio
      const audioResult = await this.localStorageService.uploadAudioFile(audioFile, userId);

      // Subir imagen de portada si existe
      let coverResult;
      if (coverFile) {
        coverResult = await this.coversStorageService.uploadCoverImage(coverFile, userId);
      }

      return {
        audio: {
          url: audioResult.url,
          fileName: audioResult.fileName,
        },
        cover: coverResult ? {
          url: coverResult.url,
          fileName: coverResult.fileName,
        } : undefined,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException(`Error al subir archivos: ${error.message}`);
    }
  }

  /**
   * Sube archivos y crea el registro de canción en una operación transaccional
   * Si falla la creación en BD, elimina los archivos subidos
   * @param audioFile Archivo de audio
   * @param coverFile Archivo de imagen (opcional)
   * @param songData Datos de la canción a crear
   * @param userId ID del usuario que sube el archivo
   * @returns Canción creada
   */
  async uploadAndCreateSong(
    audioFile: Express.Multer.File,
    coverFile: Express.Multer.File | undefined,
    songData: {
      title: string;
      artistId: string;
      albumId?: string;
      genreId?: string;
      genres?: string[]; // Array de géneros musicales
      status?: 'draft' | 'pending' | 'published' | 'rejected';
      duration?: number;
    },
    userId?: string,
  ): Promise<Song> {
    if (!audioFile) {
      throw new BadRequestException('No se proporcionó archivo de audio');
    }

    // Variables para almacenar resultados de subida (para rollback si es necesario)
    let audioResult: { url: string; key: string; fileName: string; duration: number; metadata?: any } | null = null;
    let coverResult: { url: string; key: string; fileName: string } | null = null;

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      this.logger.log(`🎵 Iniciando subida de canción: "${songData.title}"`);
      this.logger.log(`📁 Archivo de audio: ${audioFile.originalname} (${(audioFile.size / 1024 / 1024).toFixed(2)} MB)`);
      if (coverFile) {
        this.logger.log(`🖼️ Archivo de portada: ${coverFile.originalname} (${(coverFile.size / 1024 / 1024).toFixed(2)} MB)`);
      }

      // Paso 1: Subir archivos (fuera de la transacción de BD, pero necesitamos rollback manual)
      this.logger.log('📤 Subiendo archivo de audio...');
      audioResult = await this.localStorageService.uploadAudioFile(audioFile, userId);
      this.logger.log(`✅ Audio subido: ${audioResult.fileName}`);
      
      if (audioResult.duration > 0) {
        this.logger.log(`⏱️ Duración extraída: ${Math.floor(audioResult.duration / 60)}:${(audioResult.duration % 60).toString().padStart(2, '0')}`);
      } else {
        this.logger.warn('⚠️ No se pudo extraer duración del audio (duración = 0)');
      }
      
      if (coverFile) {
        this.logger.log('📤 Subiendo portada...');
        coverResult = await this.coversStorageService.uploadCoverImage(coverFile, userId);
        this.logger.log(`✅ Portada subida: ${coverResult.fileName}`);
      }

      // Usar duración extraída del audio si está disponible, sino usar la proporcionada o 0
      const finalDuration = audioResult.duration > 0 
        ? audioResult.duration 
        : (songData.duration ?? 0);
      
      this.logger.log(`⏱️ Duración final a guardar: ${finalDuration}s (${Math.floor(finalDuration / 60)}:${(finalDuration % 60).toString().padStart(2, '0')})`);
      
      // Validar que la duración sea válida antes de guardar
      if (finalDuration <= 0) {
        this.logger.warn(`⚠️ ADVERTENCIA: La duración es 0. audioResult.duration=${audioResult.duration}, songData.duration=${songData.duration}`);
      }

      // Paso 2: Validar que el artista existe (dentro de la transacción)
      this.logger.log(`🔍 Validando artista: ${songData.artistId}`);
      const artist = await queryRunner.manager.findOne(Artist, {
        where: { id: songData.artistId },
      });

      if (!artist) {
        throw new NotFoundException('Artista no encontrado');
      }
      this.logger.log(`✅ Artista validado: ${artist.stageName || artist.id}`);

      // Verificar álbum si se proporciona
      if (songData.albumId) {
        const album = await queryRunner.manager.findOne(Album, {
          where: { id: songData.albumId },
        });

        if (!album) {
          throw new NotFoundException('Álbum no encontrado');
        }
      }

      // Verificar género si se proporciona
      if (songData.genreId) {
        const genre = await queryRunner.manager.findOne(Genre, {
          where: { id: songData.genreId },
        });

        if (!genre) {
          throw new NotFoundException('Género no encontrado');
        }
      }

      // Paso 3: Crear el registro de la canción (dentro de la transacción)
      const song = queryRunner.manager.create(Song, {
        title: songData.title,
        fileUrl: audioResult.url,
        coverArtUrl: coverResult?.url,
        artistId: songData.artistId,
        albumId: songData.albumId,
        genreId: songData.genreId,
        genres: songData.genres || [], // Array de géneros musicales
        status: songData.status === 'pending' || songData.status === 'published' 
          ? SongStatus.PUBLISHED 
          : songData.status === 'draft' 
          ? SongStatus.DRAFT 
          : SongStatus.DRAFT,
        duration: finalDuration,
        totalStreams: 0,
        totalLikes: 0,
      });

      this.logger.log('💾 Guardando canción en base de datos...');
      this.logger.log(`   - Título: ${song.title}`);
      this.logger.log(`   - Duración: ${finalDuration}s (${Math.floor(finalDuration / 60)}:${(finalDuration % 60).toString().padStart(2, '0')})`);
      this.logger.log(`   - Artista ID: ${song.artistId}`);
      this.logger.log(`   - Estado: ${song.status}`);
      
      const savedSong = await queryRunner.manager.save(Song, song);

      // Commit de la transacción
      await queryRunner.commitTransaction();
      
      this.logger.log(`✅ Canción creada exitosamente: ID ${savedSong.id}`);
      this.logger.log(`📊 Duración guardada en BD: ${savedSong.duration}s (${Math.floor(savedSong.duration / 60)}:${(savedSong.duration % 60).toString().padStart(2, '0')})`);
      this.logger.log(`🎉 Subida completada: "${savedSong.title}"`);

      return savedSong;
    } catch (error) {
      this.logger.error(`❌ Error al crear canción: ${error.message}`);
      
      // Rollback de la transacción
      this.logger.log('🔄 Haciendo rollback de transacción...');
      await queryRunner.rollbackTransaction();

      // Limpiar archivos subidos si la creación en BD falló
      if (audioResult) {
        this.logger.log(`🗑️ Eliminando archivo de audio: ${audioResult.fileName}`);
        try {
          await this.localStorageService.deleteFile(audioResult.key);
          this.logger.log('✅ Archivo de audio eliminado');
        } catch (deleteError) {
          this.logger.error(`❌ Error al eliminar archivo de audio: ${deleteError.message}`);
        }
      }

      if (coverResult) {
        this.logger.log(`🗑️ Eliminando archivo de portada: ${coverResult.fileName}`);
        try {
          await this.coversStorageService.deleteFile(coverResult.key);
          this.logger.log('✅ Archivo de portada eliminado');
        } catch (deleteError) {
          this.logger.error(`❌ Error al eliminar archivo de portada: ${deleteError.message}`);
        }
      }

      // Re-lanzar el error original
      if (error instanceof BadRequestException || error instanceof NotFoundException) {
        throw error;
      }
      throw new BadRequestException(`Error al crear canción: ${error.message}`);
    } finally {
      // Liberar el query runner
      await queryRunner.release();
    }
  }


  /**
   * Crea una nueva canción en la base de datos
   * @param createSongDto Datos de la canción a crear
   * @returns Canción creada
   */
  async create(createSongDto: {
    title: string;
    fileUrl: string;
    artistId: string;
    albumId?: string;
    genreId?: string;
    genres?: string[]; // Array de géneros musicales
    coverImageUrl?: string;
    status?: 'draft' | 'pending' | 'published' | 'rejected';
    duration?: number;
  }): Promise<Song> {
    // VALIDACIÓN: Verificar que se proporcionen géneros
    if (!createSongDto.genres || createSongDto.genres.length === 0) {
      throw new BadRequestException(
        'Es obligatorio asignar al menos un género musical a la canción. ' +
        'Los géneros son necesarios para el sistema de recomendaciones.'
      );
    }

    // Verificar que el artista existe
    const artist = await this.artistRepository.findOne({
      where: { id: createSongDto.artistId },
    });

    if (!artist) {
      throw new NotFoundException('Artista no encontrado');
    }

    // Verificar álbum si se proporciona
    if (createSongDto.albumId) {
      const album = await this.albumRepository.findOne({
        where: { id: createSongDto.albumId },
      });

      if (!album) {
        throw new NotFoundException('Álbum no encontrado');
      }
    }

    // Verificar género si se proporciona
    if (createSongDto.genreId) {
      const genre = await this.genreRepository.findOne({
        where: { id: createSongDto.genreId },
      });

      if (!genre) {
        throw new NotFoundException('Género no encontrado');
      }
    }

    const song = this.songRepository.create({
      title: createSongDto.title,
      fileUrl: createSongDto.fileUrl,
      coverArtUrl: createSongDto.coverImageUrl,
      artistId: createSongDto.artistId,
      albumId: createSongDto.albumId,
      genreId: createSongDto.genreId,
      genres: createSongDto.genres || [], // Array de géneros musicales
      status: createSongDto.status === 'pending' || createSongDto.status === 'published' 
        ? SongStatus.PUBLISHED 
        : createSongDto.status === 'draft' 
        ? SongStatus.DRAFT 
        : SongStatus.DRAFT,
      duration: createSongDto.duration ?? 0,
      totalStreams: 0,
      totalLikes: 0,
    });

    return await this.songRepository.save(song);
  }

  /**
   * Actualiza una canción existente
   * @param id ID de la canción a actualizar
   * @param updateData Datos a actualizar
   * @returns Canción actualizada
   */
  async update(id: string, updateData: {
    title?: string;
    artistId?: string;
    albumId?: string;
    genreId?: string;
    genres?: string[];
    status?: SongStatus;
    isExplicit?: boolean;
    releaseDate?: Date;
    coverImageUrl?: string;
  }): Promise<Song> {
    // Buscar la canción existente
    const song = await this.songRepository.findOne({
      where: { id },
      relations: ['artist', 'album', 'genre'],
    });

    if (!song) {
      throw new NotFoundException('Canción no encontrada');
    }

    // VALIDACIÓN: Si se están actualizando los géneros, verificar que no quede vacío
    if (updateData.genres !== undefined) {
      // Verificar si los géneros están vacíos
      const genresEmpty = !updateData.genres || updateData.genres.length === 0;
      
      if (genresEmpty) {
        // Si la canción es destacada, no puede quedarse sin géneros
        if (song.isFeatured) {
          throw new BadRequestException(
            'No se pueden quitar todos los géneros de una canción destacada. ' +
            'Las canciones destacadas requieren géneros para el sistema de recomendaciones automáticas.'
          );
        }
        
        // Si no es destacada, igualmente no puede quedarse sin géneros
        throw new BadRequestException(
          'Es obligatorio mantener al menos un género musical asignado. ' +
          'Los géneros son necesarios para el sistema de recomendaciones.'
        );
      }
    }

    // Verificar artista si se está actualizando
    if (updateData.artistId) {
      const artist = await this.artistRepository.findOne({
        where: { id: updateData.artistId },
      });
      if (!artist) {
        throw new NotFoundException('Artista no encontrado');
      }
    }

    // Verificar álbum si se está actualizando
    if (updateData.albumId) {
      const album = await this.albumRepository.findOne({
        where: { id: updateData.albumId },
      });
      if (!album) {
        throw new NotFoundException('Álbum no encontrado');
      }
    }

    // Verificar género si se está actualizando
    if (updateData.genreId) {
      const genre = await this.genreRepository.findOne({
        where: { id: updateData.genreId },
      });
      if (!genre) {
        throw new NotFoundException('Género no encontrado');
      }
    }

    // Actualizar campos
    if (updateData.title !== undefined) {
      song.title = updateData.title;
    }
    if (updateData.artistId !== undefined) {
      song.artistId = updateData.artistId;
    }
    if (updateData.albumId !== undefined) {
      song.albumId = updateData.albumId;
    }
    if (updateData.genreId !== undefined) {
      song.genreId = updateData.genreId;
    }
    if (updateData.genres !== undefined) {
      song.genres = updateData.genres;
    }
    if (updateData.coverImageUrl !== undefined) {
      song.coverArtUrl = updateData.coverImageUrl;
    }
    if (updateData.status !== undefined) {
      song.status = updateData.status;
    }
    if (updateData.isExplicit !== undefined) {
      song.isExplicit = updateData.isExplicit;
    }
    if (updateData.releaseDate !== undefined) {
      song.releaseDate = updateData.releaseDate;
    }

    this.logger.log(`Actualizando canción: ${song.title} (géneros: ${song.genres?.join(', ') || 'ninguno'})`);

    return await this.songRepository.save(song);
  }

  /**
   * Actualiza una canción, soportando la sustitución física de archivos MP3 o Portadas
   * además de los metadatos de texto.
   */
  async updateWithFiles(
    id: string,
    updateData: any, // DTO de actualización
    audioFile?: Express.Multer.File,
    coverFile?: Express.Multer.File,
    userId?: string
  ): Promise<Song> {
    const song = await this.songRepository.findOne({
      where: { id },
    });

    if (!song) {
      throw new NotFoundException('Canción no encontrada');
    }

    let filesUpdated = false;

    // 1. Manejo del re-upload de AUDIO
    if (audioFile) {
      this.logger.log(`🔄 Sustituyendo archivo de audio para canción: ${song.title}`);
      if (song.fileUrl) {
        try {
          // Extraer key del URL viejo. Ej: http://.../uploads/songs/abc.mp3 -> "songs/abc.mp3"
          // O si de url local base se trata:
          const parts = song.fileUrl.split('/');
          const filename = parts[parts.length - 1];
          await this.localStorageService.deleteFile(`songs/${filename}`);
          this.logger.log(`🗑️ Archivo antiguo de audio eliminado del disco: ${filename}`);
        } catch (e) {
          this.logger.warn(`⚠️ No se pudo borrar físicamente el audio antiguo: ${e.message}. Se asume huérfano.`);
        }
      }
      
      const audioResult = await this.localStorageService.uploadAudioFile(audioFile, userId);
      song.fileUrl = audioResult.url;
      song.duration = audioResult.duration > 0 ? audioResult.duration : song.duration;
      filesUpdated = true;
    }

    // 2. Manejo del re-upload del COVER
    if (coverFile) {
      this.logger.log(`🖼️ Sustituyendo archivo de portada para canción: ${song.title}`);
      if (song.coverArtUrl) {
        try {
          const parts = song.coverArtUrl.split('/');
          const filename = parts[parts.length - 1];
          // Asume key "covers/abc.jpg" para S3/Local
          await this.coversStorageService.deleteFile(`covers/${filename}`);
          this.logger.log(`🗑️ Portada antigua eliminada del disco: ${filename}`);
        } catch (e) {
          this.logger.warn(`⚠️ No se pudo borrar físicamente la portada antigua: ${e.message}.`);
        }
      }

      const coverResult = await this.coversStorageService.uploadCoverImage(coverFile, userId);
      song.coverArtUrl = coverResult.url;
      filesUpdated = true;
    }

    // 3. Si hubo cambios en los archivos, persistir prematuramente para luego pasar a update
    if (filesUpdated) {
      this.logger.log(`💾 Guardando cambios de archivos físicos para canción: ${song.title}`);
      await this.songRepository.save(song);
    }

    // 4. Actualizar el resto de la metadato usando el flujo normal
    // Limpiamos los campos de UpdateData si vinieran objetos nulos, aunque en FormData puede que sí
    if (updateData && Object.keys(updateData).length > 0) {
      return await this.update(id, updateData);
    }

    // Recargar con relaciones por si solo se actualizaron archivos
    return await this.findOne(id);
  }

  /**
   * Elimina una canción
   * @param id ID de la canción a eliminar
   */
  async remove(id: string): Promise<void> {
    const song = await this.songRepository.findOne({
      where: { id },
    });

    if (!song) {
      throw new NotFoundException('Canción no encontrada');
    }

    await this.songRepository.remove(song);
  }


  /**
   * Actualiza la duración de una canción leyendo el archivo de audio
   * @param songId ID de la canción a actualizar
   * @returns Canción actualizada con la nueva duración
   */
  async updateDurationFromFile(songId: string): Promise<Song> {
    const song = await this.songRepository.findOne({
      where: { id: songId },
    });

    if (!song) {
      throw new NotFoundException('Canción no encontrada');
    }

    // Extraer el nombre del archivo de la URL
    const fileName = song.fileUrl.split('/').pop();
    if (!fileName) {
      throw new BadRequestException('No se pudo extraer el nombre del archivo de la URL');
    }

    // Construir la ruta del archivo
    const songsDir = path.join(process.cwd(), 'uploads', 'songs');
    const filePath = path.join(songsDir, fileName);

    // Verificar que el archivo existe
    if (!fs.existsSync(filePath)) {
      throw new NotFoundException(`Archivo no encontrado: ${filePath}`);
    }

    this.logger.log(`📂 Leyendo archivo: ${filePath}`);
    const fileBuffer = fs.readFileSync(filePath);
    
    // Determinar el MIME type basado en la extensión
    const ext = path.extname(fileName).toLowerCase();
    const mimeTypes: Record<string, string> = {
      '.mp3': 'audio/mpeg',
      '.wav': 'audio/wav',
      '.m4a': 'audio/m4a',
      '.flac': 'audio/flac',
    };
    const mimeType = mimeTypes[ext] || 'audio/mpeg';

    this.logger.log(`🔍 Extrayendo metadatos del archivo: ${fileName} (${mimeType})`);
    const metadata = await this.audioMetadataService.extractMetadata(fileBuffer, mimeType);

    if (metadata.duration > 0) {
      song.duration = Math.round(metadata.duration);
      const updatedSong = await this.songRepository.save(song);
      this.logger.log(`✅ Duración actualizada: ${song.title} - ${Math.floor(updatedSong.duration / 60)}:${(updatedSong.duration % 60).toString().padStart(2, '0')}`);
      return updatedSong;
    } else {
      throw new BadRequestException('No se pudo extraer la duración del archivo');
    }
  }

  /**
   * Actualiza las duraciones de todas las canciones que tienen duración = 0
   * @returns Número de canciones actualizadas
   */
  async updateAllDurations(): Promise<{ updated: number; failed: number; errors: string[] }> {
    this.logger.log('🔄 Iniciando actualización de duraciones de canciones...');
    
    const songs = await this.songRepository.find({
      where: { duration: 0 },
    });

    this.logger.log(`📊 Encontradas ${songs.length} canciones con duración = 0`);

    let updated = 0;
    let failed = 0;
    const errors: string[] = [];

    for (const song of songs) {
      try {
        await this.updateDurationFromFile(song.id);
        updated++;
      } catch (error) {
        failed++;
        const errorMsg = `Error al actualizar "${song.title}" (${song.id}): ${error.message}`;
        errors.push(errorMsg);
        this.logger.error(`❌ ${errorMsg}`);
      }
    }

    this.logger.log(`✅ Actualización completada: ${updated} actualizadas, ${failed} fallidas`);
    
    return { updated, failed, errors };
  }

  /**
   * Obtiene canciones publicadas optimizadas para Flutter
   * Incluye filtros opcionales por featured, artistId, genreId y búsqueda
   */
  async getPublishedSongs(
    page: number = 1,
    limit: number = 20,
    featured?: boolean,
    artistId?: string,
    genreId?: string,
    search?: string,
  ): Promise<PaginatedSongsResponseDto> {
    this.logger.log(`🔍 Buscando canciones publicadas - page: ${page}, limit: ${limit}, artistId: ${artistId || 'ninguno'}, featured: ${featured}, genreId: ${genreId || 'ninguno'}, search: ${search || 'ninguno'}`);
    
    const queryBuilder = this.songRepository
      .createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('artist.user', 'user')
      .leftJoinAndSelect('song.album', 'album')
      .leftJoinAndSelect('song.genre', 'genre')
      .where('song.status = :status', { status: SongStatus.PUBLISHED });

    // Aplicar filtros opcionales
    if (featured !== undefined) {
      queryBuilder.andWhere('song.isFeatured = :featured', { featured });
    }

    if (artistId) {
      // Validar que el artista existe
      const artist = await this.artistRepository.findOne({ where: { id: artistId } });
      if (!artist) {
        this.logger.warn(`⚠️ Artista no encontrado con ID: ${artistId}`);
      } else {
        this.logger.log(`✅ Artista encontrado: ${artist.stageName || artist.name} (ID: ${artistId})`);
      }
      
      queryBuilder.andWhere('song.artistId = :artistId', { artistId });
      this.logger.log(`✅ Filtro por artista aplicado: ${artistId}`);
      
      // Log adicional: contar canciones antes de aplicar filtros
      const countBeforeFilter = await this.songRepository.count({
        where: { artistId, status: SongStatus.PUBLISHED }
      });
      this.logger.log(`📊 Total de canciones publicadas para este artista en BD: ${countBeforeFilter}`);
    }

    if (genreId) {
      queryBuilder.andWhere('song.genreId = :genreId', { genreId });
    }

    if (search) {
      queryBuilder.andWhere(
        '(song.title ILIKE :search OR artist.stageName ILIKE :search)',
        { search: `%${search}%` },
      );
    }

    // Ordenar: destacadas primero, luego por fecha de creación
    queryBuilder.orderBy('song.isFeatured', 'DESC');
    queryBuilder.addOrderBy('song.createdAt', 'DESC');

    // Paginación
    const skip = (page - 1) * limit;
    queryBuilder.skip(skip).take(limit);

    // Log del SQL generado para debugging
    const sql = queryBuilder.getSql();
    this.logger.log(`🔍 SQL Query: ${sql}`);
    this.logger.log(`🔍 Parámetros: ${JSON.stringify(queryBuilder.getParameters())}`);
    
    const [songs, total] = await queryBuilder.getManyAndCount();
    
    this.logger.log(`✅ Encontradas ${songs.length} canciones (total: ${total}) para artista ${artistId || 'todos'}`);
    
    // Si hay canciones pero no se devuelven, log adicional
    if (artistId && songs.length === 0 && total === 0) {
      // Verificar si hay canciones con ese artistId pero con otro estado
      const allSongsForArtist = await this.songRepository.find({
        where: { artistId },
        select: ['id', 'title', 'status', 'artistId']
      });
      this.logger.warn(`⚠️ Hay ${allSongsForArtist.length} canciones para este artista, pero ninguna está publicada:`);
      allSongsForArtist.forEach(song => {
        this.logger.warn(`  - "${song.title}": status=${song.status}, artistId=${song.artistId}`);
      });
    }

    const totalPages = Math.ceil(total / limit);

    return {
      songs: SongMapper.toDtoArray(songs),
      total,
      page,
      limit,
      totalPages,
      hasNext: page < totalPages,
      hasPrevious: page > 1,
    };
  }

  /**
   * Obtiene canciones destacadas optimizadas
   */
  async getFeaturedSongs(
    page: number = 1,
    limit: number = 20,
  ): Promise<PaginatedSongsResponseDto> {
    return this.getPublishedSongs(page, limit, true);
  }

  /**
   * Obtiene el feed del home con canciones destacadas y nuevas
   */
  async getHomeFeed(
    featuredLimit: number = 10,
    newSongsLimit: number = 20,
  ): Promise<HomeFeedResponseDto> {
    // Obtener canciones destacadas
    const featuredQuery = this.songRepository
      .createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('artist.user', 'user')
      .leftJoinAndSelect('song.album', 'album')
      .leftJoinAndSelect('song.genre', 'genre')
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere('song.isFeatured = :featured', { featured: true })
      .orderBy('song.createdAt', 'DESC')
      .take(featuredLimit);

    const featuredSongs = await featuredQuery.getMany();

    // Obtener canciones nuevas (no destacadas)
    const newSongsQuery = this.songRepository
      .createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('artist.user', 'user')
      .leftJoinAndSelect('song.album', 'album')
      .leftJoinAndSelect('song.genre', 'genre')
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .orderBy('song.createdAt', 'DESC')
      .take(newSongsLimit);

    const newSongs = await newSongsQuery.getMany();

    const total = await this.songRepository.count({
      where: { status: SongStatus.PUBLISHED },
    });

    return {
      featured: SongMapper.toDtoArray(featuredSongs),
      newSongs: SongMapper.toDtoArray(newSongs),
      pagination: {
        page: 1,
        limit: featuredLimit + newSongsLimit,
        total,
        totalPages: Math.ceil(total / (featuredLimit + newSongsLimit)),
      },
    };
  }

  /**
   * Marca o desmarca una canción como destacada
   */
  async toggleFeatured(songId: string, featured: boolean): Promise<Song> {
    const song = await this.songRepository.findOne({
      where: { id: songId },
    });

    if (!song) {
      throw new NotFoundException('Canción no encontrada');
    }

    // VALIDACIÓN: Una canción destacada debe tener géneros para el sistema de recomendaciones
    if (featured && (!song.genres || song.genres.length === 0)) {
      throw new BadRequestException(
        'No se puede destacar una canción sin géneros musicales. ' +
        'Los géneros son necesarios para el sistema de recomendaciones automáticas.'
      );
    }

    song.isFeatured = featured;
    return await this.songRepository.save(song);
  }

  /**
   * Obtiene una canción recomendada basada en géneros compartidos
   * 
   * LÓGICA MEJORADA:
   * 1. Obtiene los géneros de la canción actual
   * 2. Busca canciones que compartan EXACTAMENTE al menos un género
   * 3. Prioriza coincidencias exactas de género
   * 4. Si no encuentra coincidencias exactas, busca coincidencias parciales
   * 5. Como último recurso, elige una canción aleatoria
   * 
   * @param currentSongId ID de la canción actual
   * @param currentGenres Géneros de la canción actual (opcional, se obtiene de la BD si no se proporciona)
   * @returns Canción recomendada o null si no hay canciones disponibles
   */
  async getRecommendedSong(currentSongId: string, currentGenres?: string[]): Promise<Song | null> {
    this.logger.log(`[getRecommendedSong] 🎵 MEJORADO: Buscando siguiente canción con género similar`);
    
    // Obtener géneros de la canción actual
    let genres = currentGenres;
    if (!genres || genres.length === 0) {
      const currentSong = await this.songRepository.findOne({ 
        where: { id: currentSongId },
        select: ['id', 'genres', 'title']
      });
      genres = currentSong?.genres || [];
      this.logger.log(`[getRecommendedSong] Géneros obtenidos de BD: ${genres.join(', ') || 'ninguno'}`);
    } else {
      this.logger.log(`[getRecommendedSong] Géneros proporcionados: ${genres.join(', ')}`);
    }

    if (!genres || genres.length === 0) {
      this.logger.log(`[getRecommendedSong] ❌ Sin géneros, usando canción aleatoria`);
      return this.getRandomSong(currentSongId);
    }

    // Normalizar géneros para comparación
    const normalizedGenres = genres.map(g => g.toLowerCase().trim());
    this.logger.log(`[getRecommendedSong] Géneros normalizados: ${normalizedGenres.join(', ')}`);

    // PASO 1: Buscar coincidencias EXACTAS de género
    const exactMatches = await this.findSongsByExactGenres(currentSongId, normalizedGenres);
    if (exactMatches.length > 0) {
      const selected = exactMatches[Math.floor(Math.random() * exactMatches.length)];
      this.logger.log(`[getRecommendedSong] ✅ COINCIDENCIA EXACTA: ${selected.title} (géneros: ${selected.genres?.join(', ') || 'ninguno'})`);
      return selected;
    }

    // PASO 2: Buscar coincidencias PARCIALES (contiene el género)
    const partialMatches = await this.findSongsByPartialGenres(currentSongId, normalizedGenres);
    if (partialMatches.length > 0) {
      const selected = partialMatches[Math.floor(Math.random() * partialMatches.length)];
      this.logger.log(`[getRecommendedSong] ✅ COINCIDENCIA PARCIAL: ${selected.title} (géneros: ${selected.genres?.join(', ') || 'ninguno'})`);
      return selected;
    }

    // PASO 3: Fallback - canción aleatoria
    this.logger.log(`[getRecommendedSong] ⚠️ Sin coincidencias de género, usando canción aleatoria`);
    return this.getRandomSong(currentSongId);
  }

  /**
   * Busca canciones que tengan EXACTAMENTE los mismos géneros - CONSULTA DIRECTA EN BD
   */
  private async findSongsByExactGenres(currentSongId: string, normalizedGenres: string[]): Promise<Song[]> {
    try {
      this.logger.log(`[findSongsByExactGenres] 🔍 Consultando BD para géneros: ${normalizedGenres.join(', ')}`);
      
      // CONSULTA SQL DIRECTA para buscar por género en la base de datos
      const queryBuilder = this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.id != :currentSongId', { currentSongId })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' })
        .andWhere('song.fileUrl LIKE :httpUrl', { httpUrl: 'http%' });

      // Agregar condiciones OR para cada género
      const genreConditions = normalizedGenres.map((genre, index) => 
        `LOWER(song.genres) LIKE :genre${index}`
      ).join(' OR ');
      
      if (genreConditions) {
        queryBuilder.andWhere(`(${genreConditions})`);
        
        // Agregar parámetros para cada género
        normalizedGenres.forEach((genre, index) => {
          queryBuilder.setParameter(`genre${index}`, `%${genre}%`);
        });
      }

      const exactMatches = await queryBuilder
        .orderBy('song.totalStreams', 'DESC') // Priorizar canciones más populares
        .limit(20) // Limitar resultados
        .getMany();

      this.logger.log(`[findSongsByExactGenres] ✅ Encontradas ${exactMatches.length} coincidencias exactas en BD`);
      
      // Log de las canciones encontradas
      exactMatches.forEach(song => {
        this.logger.log(`[findSongsByExactGenres] - ${song.title} (géneros: ${song.genres?.join(', ') || 'ninguno'})`);
      });
      
      return exactMatches;
    } catch (error) {
      this.logger.error(`[findSongsByExactGenres] Error: ${error.message}`);
      return [];
    }
  }

  /**
   * Busca canciones que contengan parcialmente los géneros - CONSULTA DIRECTA EN BD
   */
  private async findSongsByPartialGenres(currentSongId: string, normalizedGenres: string[]): Promise<Song[]> {
    try {
      this.logger.log(`[findSongsByPartialGenres] 🔍 Consultando BD para coincidencias parciales: ${normalizedGenres.join(', ')}`);
      
      // CONSULTA SQL DIRECTA para coincidencias parciales
      const queryBuilder = this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.id != :currentSongId', { currentSongId })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' })
        .andWhere('song.fileUrl LIKE :httpUrl', { httpUrl: 'http%' });

      // Agregar condiciones OR más amplias para coincidencias parciales
      const genreConditions = normalizedGenres.map((genre, index) => 
        `(LOWER(song.genres) LIKE :genreStart${index} OR LOWER(song.genres) LIKE :genreEnd${index} OR LOWER(song.genres) LIKE :genreMiddle${index})`
      ).join(' OR ');
      
      if (genreConditions) {
        queryBuilder.andWhere(`(${genreConditions})`);
        
        // Agregar parámetros para cada género con diferentes patrones
        normalizedGenres.forEach((genre, index) => {
          queryBuilder.setParameter(`genreStart${index}`, `${genre}%`);
          queryBuilder.setParameter(`genreEnd${index}`, `%${genre}`);
          queryBuilder.setParameter(`genreMiddle${index}`, `%${genre}%`);
        });
      }

      const partialMatches = await queryBuilder
        .orderBy('song.createdAt', 'DESC') // Priorizar canciones más recientes
        .limit(15) // Limitar resultados
        .getMany();

      this.logger.log(`[findSongsByPartialGenres] ✅ Encontradas ${partialMatches.length} coincidencias parciales en BD`);
      
      // Log de las canciones encontradas
      partialMatches.forEach(song => {
        this.logger.log(`[findSongsByPartialGenres] - ${song.title} (géneros: ${song.genres?.join(', ') || 'ninguno'})`);
      });
      
      return partialMatches;
    } catch (error) {
      this.logger.error(`[findSongsByPartialGenres] Error: ${error.message}`);
      return [];
    }
  }

  /**
   * Obtiene una canción aleatoria como fallback - CONSULTA DIRECTA EN BD
   */
  private async getRandomSong(currentSongId: string): Promise<Song | null> {
    try {
      this.logger.log(`[getRandomSong] 🔍 Consultando BD para canción aleatoria`);
      
      // CONSULTA SQL DIRECTA para canción aleatoria con URLs válidas
      const randomSong = await this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.id != :currentSongId', { currentSongId })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' })
        .andWhere('song.fileUrl LIKE :httpUrl', { httpUrl: 'http%' })
        .orderBy('RANDOM()') // Orden aleatorio
        .limit(1)
        .getOne();

      if (randomSong) {
        this.logger.log(`[getRandomSong] ✅ Canción aleatoria seleccionada: ${randomSong.title} (géneros: ${randomSong.genres?.join(', ') || 'ninguno'})`);
        this.logger.log(`[getRandomSong] URL: ${randomSong.fileUrl}`);
      } else {
        this.logger.log(`[getRandomSong] ❌ No hay canciones válidas disponibles en BD`);
      }
      
      return randomSong;
    } catch (error) {
      this.logger.error(`[getRandomSong] Error: ${error.message}`);
      return null;
    }
  }

  /**
   * Obtiene una canción por ID optimizada para Flutter
   */
  async findOneOptimized(id: string): Promise<SongResponseDto> {
    const song = await this.songRepository.findOne({
      where: { id, status: SongStatus.PUBLISHED },
      relations: ['artist', 'artist.user', 'album', 'genre'],
    });

    if (!song) {
      throw new NotFoundException('Canción no encontrada');
    }

    return SongMapper.toDto(song);
  }
}









