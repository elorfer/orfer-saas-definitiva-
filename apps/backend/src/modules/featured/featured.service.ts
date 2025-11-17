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
    
    // Solo artistas destacados que tengan foto de perfil y portada
    return this.artistRepository
      .createQueryBuilder('artist')
      .leftJoinAndSelect('artist.user', 'user')
      .where('artist.isFeatured = :isFeatured', { isFeatured: true })
      // Aceptar artistas que tengan al menos UNA imagen (perfil o portada)
      .andWhere('(artist.profilePhotoUrl IS NOT NULL OR artist.coverPhotoUrl IS NOT NULL)')
      .orderBy('artist.updatedAt', 'DESC')
      .limit(validLimit)
      .getMany();
  }

  async getFeaturedPlaylists(limit: number = 10) {
    // Validar y limitar el límite para evitar consultas costosas
    const validLimit = Math.min(Math.max(1, limit), 100);
    
    return this.playlistRepository.find({
      where: { isFeatured: true, visibility: PlaylistVisibility.PUBLIC },
      relations: ['user'],
      order: { createdAt: 'DESC' },
      take: validLimit,
    });
  }

  async setSongFeatured(songId: string, featured: boolean) {
    // Usar update() para mejor rendimiento (una sola query)
    const updateResult = await this.songRepository.update(
      { id: songId },
      { isFeatured: featured },
    );

    if (updateResult.affected === 0) {
      throw new NotFoundException('Canción no encontrada');
    }

    // Obtener la canción actualizada para retornarla
    const song = await this.songRepository.findOne({
      where: { id: songId },
      relations: ['artist', 'album', 'genre'],
    });

    this.logger.log(`Canción "${song?.title || songId}" ${featured ? 'destacada' : 'ya no está destacada'}`);

    return song;
  }

  async setArtistFeatured(artistId: string, featured: boolean) {
    // Si se quiere destacar, validar que tenga imágenes cargadas
    if (featured) {
      const toValidate = await this.artistRepository.findOne({ where: { id: artistId } });
      if (!toValidate) {
        throw new NotFoundException('Artista no encontrado');
      }
      if (!toValidate.profilePhotoUrl || !toValidate.coverPhotoUrl) {
        throw new BadRequestException('Para destacar un artista, debe tener foto de perfil y portada cargadas');
      }
    }
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

