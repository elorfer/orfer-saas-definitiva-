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

    // 1) Primero, canciones marcadas explícitamente como destacadas
    const featuredExplicit = await this.songRepository.find({
      where: { isFeatured: true, status: SongStatus.PUBLISHED },
      relations: ['artist', 'album', 'genre'],
      order: { createdAt: 'DESC' },
      take: validLimit,
    });

    if (featuredExplicit.length >= validLimit) {
      return featuredExplicit.slice(0, validLimit);
    }

    // 2) Si faltan, completar con canciones de artistas destacados (sin duplicar)
    const remaining = validLimit - featuredExplicit.length;
    const explicitIds = new Set(featuredExplicit.map((s) => s.id));

    const fromFeaturedArtists = await this.songRepository
      .createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('song.album', 'album')
      .leftJoinAndSelect('song.genre', 'genre')
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere('artist.isFeatured = true')
      .orderBy('song.createdAt', 'DESC')
      .limit(remaining * 2) // pedir un poco más para filtrar duplicados si hay
      .getMany();

    const deduped = fromFeaturedArtists.filter((s) => !explicitIds.has(s.id));
    return [...featuredExplicit, ...deduped.slice(0, remaining)];
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

    // VALIDACIÓN: Si se está destacando, verificar que tenga géneros asignados
    if (featured && (!song.genres || song.genres.length === 0)) {
      throw new BadRequestException(
        'No se puede destacar una canción sin géneros asignados. ' +
        'Por favor, asigna al menos un género musical antes de destacar esta canción.'
      );
    }

    // VALIDACIÓN: Si se está destacando, verificar que esté publicada
    if (featured && song.status !== SongStatus.PUBLISHED) {
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

    this.logger.log(`Canción "${song.title}" ${featured ? 'destacada' : 'ya no está destacada'}`);
    
    if (featured) {
      this.logger.log(`Géneros de la canción destacada: ${song.genres?.join(', ') || 'ninguno'}`);
    }

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

    this.logger.log(`Artista "${artist?.stageName || artistId}" ${featured ? 'destacado' : 'ya no está destacado'}`);

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

    this.logger.log(`Playlist "${playlist?.name || playlistId}" ${featured ? 'destacada' : 'ya no está destacada'}`);

    return playlist;
  }
}

