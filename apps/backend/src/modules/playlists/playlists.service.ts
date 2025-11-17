import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';

import { Playlist } from '../../common/entities/playlist.entity';
import { User } from '../../common/entities/user.entity';
import { Song } from '../../common/entities/song.entity';
import { PlaylistSong } from '../../common/entities/playlist-song.entity';
import { PlaylistVisibility } from '../../common/enums/playlist.enum';
import { CreatePlaylistDto } from './dto/create-playlist.dto';
import { UpdatePlaylistDto } from './dto/update-playlist.dto';
import { PlaylistMapper, PlaylistResponseDto } from './mappers/playlist.mapper';

@Injectable()
export class PlaylistsService {
  constructor(
    @InjectRepository(Playlist)
    private readonly playlistRepository: Repository<Playlist>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
    @InjectRepository(PlaylistSong)
    private readonly playlistSongRepository: Repository<PlaylistSong>,
  ) {}

  async findAll(page: number = 1, limit: number = 10): Promise<{ playlists: PlaylistResponseDto[]; total: number }> {
    const [playlists, total] = await this.playlistRepository.findAndCount({
      where: { visibility: PlaylistVisibility.PUBLIC },
      relations: ['user', 'playlistSongs', 'playlistSongs.song', 'playlistSongs.song.artist'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    // Actualizar contadores de canciones y duración para cada playlist
    playlists.forEach(playlist => {
      playlist.updateTrackCount();
      playlist.updateTotalDuration();
    });

    // Transformar a DTOs para devolver en formato camelCase
    return { 
      playlists: PlaylistMapper.toResponseDtoArray(playlists), 
      total 
    };
  }

  async findAllForAdmin(page: number = 1, limit: number = 10): Promise<{ playlists: Playlist[]; total: number }> {
    const [playlists, total] = await this.playlistRepository.findAndCount({
      relations: ['user', 'playlistSongs', 'playlistSongs.song', 'playlistSongs.song.artist'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    // Actualizar contadores
    playlists.forEach(playlist => {
      playlist.updateTrackCount();
      playlist.updateTotalDuration();
    });

    return { playlists, total };
  }

  /**
   * Obtiene una playlist como entidad (para uso interno/admin)
   */
  async findOneEntity(id: string): Promise<Playlist> {
    const playlist = await this.playlistRepository.findOne({
      where: { id },
      relations: ['user', 'playlistSongs', 'playlistSongs.song', 'playlistSongs.song.artist'],
    });

    if (!playlist) {
      throw new NotFoundException('Playlist no encontrada');
    }

    return playlist;
  }

  /**
   * Obtiene una playlist como DTO para el admin (todas las playlists, sin filtro de visibilidad)
   */
  async findOneForAdmin(id: string): Promise<PlaylistResponseDto> {
    const playlist = await this.playlistRepository.findOne({
      where: { id },
      relations: ['user', 'playlistSongs', 'playlistSongs.song', 'playlistSongs.song.artist'],
    });

    if (!playlist) {
      throw new NotFoundException('Playlist no encontrada');
    }

    // Actualizar contadores
    playlist.updateTrackCount();
    playlist.updateTotalDuration();

    // Transformar a DTO para devolver en formato camelCase
    return PlaylistMapper.toResponseDto(playlist);
  }

  /**
   * Obtiene una playlist como DTO (para uso público/móvil)
   * Solo devuelve playlists públicas
   */
  async findOne(id: string): Promise<PlaylistResponseDto> {
    const playlist = await this.playlistRepository.findOne({
      where: { id, visibility: PlaylistVisibility.PUBLIC },
      relations: ['user', 'playlistSongs', 'playlistSongs.song', 'playlistSongs.song.artist'],
    });

    if (!playlist) {
      throw new NotFoundException('Playlist no encontrada');
    }

    // Actualizar contadores
    playlist.updateTrackCount();
    playlist.updateTotalDuration();

    // Transformar a DTO para devolver en formato camelCase
    return PlaylistMapper.toResponseDto(playlist);
  }

  async findByUser(userId: string, page: number = 1, limit: number = 10): Promise<{ playlists: Playlist[]; total: number }> {
    const [playlists, total] = await this.playlistRepository.findAndCount({
      where: { userId },
      relations: ['user', 'playlistSongs', 'playlistSongs.song'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    // Actualizar contadores
    playlists.forEach(playlist => {
      playlist.updateTrackCount();
      playlist.updateTotalDuration();
    });

    return { playlists, total };
  }

  async getFeaturedPlaylists(limit: number = 10): Promise<PlaylistResponseDto[]> {
    const playlists = await this.playlistRepository.find({
      where: { isFeatured: true, visibility: PlaylistVisibility.PUBLIC },
      relations: ['user', 'playlistSongs', 'playlistSongs.song', 'playlistSongs.song.artist'],
      order: { createdAt: 'DESC' },
      take: limit,
    });

    // Actualizar contadores
    playlists.forEach(playlist => {
      playlist.updateTrackCount();
      playlist.updateTotalDuration();
    });

    // Transformar a DTOs para devolver en formato camelCase
    return PlaylistMapper.toResponseDtoArray(playlists);
  }

  async createPlaylist(userId: string, playlistData: CreatePlaylistDto): Promise<PlaylistResponseDto> {
    // Verificar que el usuario existe
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Usuario no encontrado');
    }

    // Crear la playlist
    const playlist = this.playlistRepository.create({
      name: playlistData.name,
      description: playlistData.description,
      coverArtUrl: playlistData.coverArtUrl,
      userId,
      isFeatured: playlistData.isFeatured || false,
      visibility: PlaylistVisibility.PUBLIC,
      totalTracks: 0,
      totalDuration: 0,
      totalFollowers: 0,
    });

    const savedPlaylist = await this.playlistRepository.save(playlist);

    // Agregar canciones si se proporcionaron
    if (playlistData.songIds && playlistData.songIds.length > 0) {
      await this.addSongsToPlaylist(savedPlaylist.id, playlistData.songIds, userId);
    }

    // Retornar la playlist con sus relaciones
    return this.findOne(savedPlaylist.id);
  }

  async updatePlaylist(id: string, userId: string, updateData: UpdatePlaylistDto): Promise<PlaylistResponseDto> {
    const playlist = await this.findOneEntity(id);

    // Verificar permisos (solo el dueño puede editar, excepto si es admin)
    // Por ahora permitimos editar si el usuario es el dueño
    if (playlist.userId !== userId) {
      // En el futuro, verificar si el usuario es admin
      throw new ForbiddenException('No tienes permisos para editar esta playlist');
    }

    // Actualizar campos básicos
    if (updateData.name !== undefined) {
      playlist.name = updateData.name;
    }
    if (updateData.description !== undefined) {
      playlist.description = updateData.description;
    }
    if (updateData.coverArtUrl !== undefined) {
      playlist.coverArtUrl = updateData.coverArtUrl;
    }
    if (updateData.isFeatured !== undefined) {
      playlist.isFeatured = updateData.isFeatured;
    }

    await this.playlistRepository.save(playlist);

    // Si se proporcionaron nuevas canciones, actualizar la lista
    if (updateData.songIds !== undefined) {
      // Eliminar canciones existentes
      await this.playlistSongRepository.delete({ playlistId: id });

      // Agregar nuevas canciones
      if (updateData.songIds.length > 0) {
        await this.addSongsToPlaylist(id, updateData.songIds, userId);
      }
    }

    return this.findOne(id);
  }

  async deletePlaylist(id: string, userId: string): Promise<void> {
    const playlist = await this.findOneEntity(id);

    if (playlist.userId !== userId) {
      throw new ForbiddenException('No tienes permisos para eliminar esta playlist');
    }

    await this.playlistRepository.remove(playlist);
  }

  async addSongToPlaylist(playlistId: string, songId: string, userId: string): Promise<void> {
    const playlist = await this.findOne(playlistId);

    if (playlist.userId !== userId) {
      throw new ForbiddenException('No tienes permisos para editar esta playlist');
    }

    const song = await this.songRepository.findOne({ where: { id: songId } });
    if (!song) {
      throw new NotFoundException('Canción no encontrada');
    }

    // Verificar si la canción ya está en la playlist
    const existing = await this.playlistSongRepository.findOne({
      where: { playlistId, songId },
    });

    if (existing) {
      throw new BadRequestException('La canción ya está en esta playlist');
    }

    // Obtener la siguiente posición
    const maxPosition = await this.playlistSongRepository
      .createQueryBuilder('ps')
      .where('ps.playlistId = :playlistId', { playlistId })
      .select('MAX(ps.position)', 'max')
      .getRawOne();

    const nextPosition = (maxPosition?.max ?? -1) + 1;

    // Crear la relación
    const playlistSong = this.playlistSongRepository.create({
      playlistId,
      songId,
      position: nextPosition,
    });

    await this.playlistSongRepository.save(playlistSong);

    // Actualizar contadores
    await this.updatePlaylistCounters(playlistId);
  }

  async removeSongFromPlaylist(playlistId: string, songId: string, userId: string): Promise<void> {
    const playlist = await this.findOneEntity(playlistId);

    if (playlist.userId !== userId) {
      throw new ForbiddenException('No tienes permisos para editar esta playlist');
    }

    const playlistSong = await this.playlistSongRepository.findOne({
      where: { playlistId, songId },
    });

    if (!playlistSong) {
      throw new NotFoundException('La canción no está en esta playlist');
    }

    await this.playlistSongRepository.remove(playlistSong);

    // Reordenar posiciones restantes
    await this.reorderPlaylistSongs(playlistId);

    // Actualizar contadores
    await this.updatePlaylistCounters(playlistId);
  }

  async toggleFeatured(id: string, userId: string): Promise<PlaylistResponseDto> {
    const playlist = await this.findOneEntity(id);

    // Permitir a cualquier usuario autenticado destacar/desdestacar
    // En el futuro, solo admin debería poder hacer esto
    playlist.isFeatured = !playlist.isFeatured;
    await this.playlistRepository.save(playlist);
    
    // Retornar como DTO (admin puede ver todas las playlists)
    return this.findOneForAdmin(id);
  }

  private async addSongsToPlaylist(playlistId: string, songIds: string[], userId: string): Promise<void> {
    // Verificar que todas las canciones existen
    const songs = await this.songRepository.find({
      where: { id: In(songIds) },
    });

    if (songs.length !== songIds.length) {
      throw new BadRequestException('Una o más canciones no existen');
    }

    // Obtener la siguiente posición
    const maxPosition = await this.playlistSongRepository
      .createQueryBuilder('ps')
      .where('ps.playlistId = :playlistId', { playlistId })
      .select('MAX(ps.position)', 'max')
      .getRawOne();

    let nextPosition = (maxPosition?.max ?? -1) + 1;

    // Crear relaciones para cada canción
    const playlistSongs = songIds.map(songId => {
      return this.playlistSongRepository.create({
        playlistId,
        songId,
        position: nextPosition++,
      });
    });

    await this.playlistSongRepository.save(playlistSongs);

    // Actualizar contadores
    await this.updatePlaylistCounters(playlistId);
  }

  private async reorderPlaylistSongs(playlistId: string): Promise<void> {
    const playlistSongs = await this.playlistSongRepository.find({
      where: { playlistId },
      order: { position: 'ASC' },
    });

    // Reordenar posiciones desde 0
    for (let i = 0; i < playlistSongs.length; i++) {
      playlistSongs[i].position = i;
      await this.playlistSongRepository.save(playlistSongs[i]);
    }
  }

  private async updatePlaylistCounters(playlistId: string): Promise<void> {
    // Recargar la playlist con todas las relaciones necesarias
    const playlist = await this.playlistRepository.findOne({
      where: { id: playlistId },
      relations: ['playlistSongs', 'playlistSongs.song'],
    });
    
    if (!playlist) {
      return;
    }
    
    // Actualizar contadores usando las relaciones cargadas
    playlist.updateTrackCount();
    playlist.updateTotalDuration();

    await this.playlistRepository.save(playlist);
  }
}
