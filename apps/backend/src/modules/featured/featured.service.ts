import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Song, SongStatus } from '../../common/entities/song.entity';
import { Artist } from '../../common/entities/artist.entity';
import { Playlist, PlaylistVisibility } from '../../common/entities/playlist.entity';

@Injectable()
export class FeaturedService {
  private readonly logger = new Logger(FeaturedService.name);

  constructor(
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
    @InjectRepository(Artist)
    private readonly artistRepository: Repository<Artist>,
    @InjectRepository(Playlist)
    private readonly playlistRepository: Repository<Playlist>,
  ) {}

  async getFeaturedSongs(limit: number = 10) {
    // Validar y limitar el límite para evitar consultas costosas
    const validLimit = Math.min(Math.max(1, limit), 100);

    // SOLO devolver canciones marcadas explícitamente como destacadas por el admin
    // NO completar con canciones de artistas destacados
    const featuredExplicit = await this.songRepository.find({
      where: { isFeatured: true, status: SongStatus.PUBLISHED },
      relations: ['artist', 'album', 'genre'],
      order: { createdAt: 'DESC' },
      take: validLimit,
    });

    // Log resumido para diagnóstico (solo en modo debug)
    if (featuredExplicit.length > 0) {
      this.logger.debug(`[getFeaturedSongs] Encontradas ${featuredExplicit.length} canciones destacadas`);
    }

    // Devolver SOLO las canciones explícitamente destacadas (puede ser menos que el límite)
    return featuredExplicit;
  }

  async getFeaturedArtists(limit: number = 10) {
    // Validar y limitar el límite para evitar consultas costosas
    const validLimit = Math.min(Math.max(1, limit), 100);
    
    // Artistas destacados (sin requerir imágenes, la app móvil puede manejar imágenes nulas)
    return this.artistRepository
      .createQueryBuilder('artist')
      .leftJoinAndSelect('artist.user', 'user')
      .where('artist.isFeatured = :isFeatured', { isFeatured: true })
      .orderBy('artist.updatedAt', 'DESC')
      .limit(validLimit)
      .getMany();
  }

  async getFeaturedPlaylists(limit: number = 10) {
    // Validar y limitar el límite para evitar consultas costosas
    const validLimit = Math.min(Math.max(1, limit), 100);
    
    // Cargar todas las relaciones necesarias para mapear correctamente a DTOs
    const playlists = await this.playlistRepository.find({
      where: { isFeatured: true, visibility: PlaylistVisibility.PUBLIC },
      relations: ['user', 'playlistSongs', 'playlistSongs.song', 'playlistSongs.song.artist'],
      order: { createdAt: 'DESC' },
      take: validLimit,
    });

    // Actualizar contadores para asegurar que los datos sean precisos
    playlists.forEach(playlist => {
      playlist.updateTrackCount();
      playlist.updateTotalDuration();
    });

    return playlists;
  }

  async setSongFeatured(songId: string, featured: boolean) {
    // Obtener la canción primero para validaciones
    const song = await this.songRepository.findOne({
      where: { id: songId },
      relations: ['artist', 'album', 'genre'],
    });

    if (!song) {
      throw new NotFoundException('Canción no encontrada');
    }

    // ✅ OPTIMIZACIÓN PRODUCCIÓN: Logs solo en modo debug
    this.logger.debug(`Intentando ${featured ? 'destacar' : 'quitar destacado'} canción: ${song.title} (ID: ${songId})`);
    this.logger.debug(`Estado actual: status=${song.status}, isFeatured=${song.isFeatured}, genres=${JSON.stringify(song.genres)}`);

    // VALIDACIÓN: Si se está destacando, verificar que tenga géneros asignados
    if (featured && (!song.genres || song.genres.length === 0)) {
      this.logger.warn(`No se puede destacar canción ${songId}: no tiene géneros asignados`);
      throw new BadRequestException(
        'No se puede destacar una canción sin géneros asignados. ' +
        'Por favor, asigna al menos un género musical antes de destacar esta canción.'
      );
    }

    // VALIDACIÓN: Si se está destacando, verificar que esté publicada
    if (featured && song.status !== SongStatus.PUBLISHED) {
      this.logger.warn(`No se puede destacar canción ${songId}: estado=${song.status}, requiere PUBLISHED`);
      throw new BadRequestException(
        'Solo se pueden destacar canciones que estén publicadas. ' +
        'Por favor, publica la canción antes de destacarla.'
      );
    }

    // Usar update() para mejor rendimiento (una sola query)
    const updateResult = await this.songRepository.update(
      { id: songId },
      { isFeatured: featured },
    );

    if (updateResult.affected === 0) {
      throw new NotFoundException('Error al actualizar el estado de la canción');
    }

    // Actualizar el objeto song con el nuevo estado
    song.isFeatured = featured;

    // ✅ OPTIMIZACIÓN PRODUCCIÓN: Log resumido solo
    this.logger.debug(`Canción "${song.title}" ${featured ? 'destacada' : 'ya no está destacada'}`);

    return song;
  }

  async setArtistFeatured(artistId: string, featured: boolean) {
    // Validar que el artista existe
    const toValidate = await this.artistRepository.findOne({ where: { id: artistId } });
    if (!toValidate) {
      throw new NotFoundException('Artista no encontrado');
    }
    
    // Ya no se requiere que tenga imágenes para ser destacado
    // La app móvil puede manejar artistas sin imágenes mostrando placeholders
    
    // Usar update() para mejor rendimiento (una sola query)
    const updateResult = await this.artistRepository.update(
      { id: artistId },
      { isFeatured: featured },
    );

    if (updateResult.affected === 0) {
      throw new NotFoundException('Artista no encontrado');
    }

    // Obtener el artista actualizado para retornarlo
    const artist = await this.artistRepository.findOne({
      where: { id: artistId },
      relations: ['user'],
    });

    // ✅ OPTIMIZACIÓN PRODUCCIÓN: Log solo en modo debug
    this.logger.debug(`Artista "${artist?.stageName || artistId}" ${featured ? 'destacado' : 'ya no está destacado'}`);

    return artist;
  }

  async setPlaylistFeatured(playlistId: string, featured: boolean) {
    // Usar update() para mejor rendimiento (una sola query)
    const updateResult = await this.playlistRepository.update(
      { id: playlistId },
      { isFeatured: featured },
    );

    if (updateResult.affected === 0) {
      throw new NotFoundException('Playlist no encontrada');
    }

    // Obtener la playlist actualizada para retornarla
    const playlist = await this.playlistRepository.findOne({
      where: { id: playlistId },
      relations: ['user'],
    });

    // ✅ OPTIMIZACIÓN PRODUCCIÓN: Log solo en modo debug
    this.logger.debug(`Playlist "${playlist?.name || playlistId}" ${featured ? 'destacada' : 'ya no está destacada'}`);

    return playlist;
  }
}

