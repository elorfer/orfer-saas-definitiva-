import { Injectable, NotFoundException, ForbiddenException, BadRequestException, Inject, forwardRef } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Artist } from '../../common/entities/artist.entity';
import { User } from '../../common/entities/user.entity';
import { Song } from '../../common/entities/song.entity';
import { Album } from '../../common/entities/album.entity';
import { CoversStorageService } from '../covers/covers-storage.service';
import { FeaturedService } from '../featured/featured.service';

@Injectable()
export class ArtistsService {
  constructor(
    @InjectRepository(Artist)
    private readonly artistRepository: Repository<Artist>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
    @InjectRepository(Album)
    private readonly albumRepository: Repository<Album>,
    private readonly coversStorageService: CoversStorageService,
    @Inject(forwardRef(() => FeaturedService))
    private readonly featuredService?: FeaturedService,
  ) {}

  async findAll(page: number = 1, limit: number = 10): Promise<{ artists: Artist[]; total: number }> {
    // Listar todos los artistas (con o sin usuario asociado)
    const [artists, total] = await this.artistRepository
      .createQueryBuilder('artist')
      .leftJoinAndSelect('artist.user', 'user')
      .leftJoinAndSelect('artist.songs', 'songs')
      .leftJoinAndSelect('artist.albums', 'albums')
      .orderBy('artist.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();

    return { artists, total };
  }

  /**
   * @deprecated Usar FeaturedService.getFeaturedArtists() en su lugar (más consistente)
   * Mantenido por compatibilidad con código existente
   */
  async findFeatured(limit: number = 20): Promise<Artist[]> {
    // Delegar a FeaturedService para consistencia (mismo ordenamiento y validación)
    if (this.featuredService) {
      return this.featuredService.getFeaturedArtists(limit);
    }
    // Fallback si FeaturedService no está disponible
    return this.artistRepository.find({
      where: { isFeatured: true },
      order: { updatedAt: 'DESC' },
      take: limit,
      relations: ['user'],
    });
  }

  async findOne(id: string): Promise<Artist> {
    const artist = await this.artistRepository.findOne({
      where: { id },
      relations: ['user', 'songs', 'albums'],
    });

    if (!artist) {
      throw new NotFoundException('Artista no encontrado');
    }

    return artist;
  }

  async findByUserId(userId: string): Promise<Artist> {
    const artist = await this.artistRepository.findOne({
      where: { userId },
      relations: ['user', 'songs', 'albums'],
    });

    if (!artist) {
      throw new NotFoundException('Artista no encontrado');
    }

    return artist;
  }

  async getArtistStats(artistId: string): Promise<any> {
    const artist = await this.findOne(artistId);
    
    const totalSongs = await this.songRepository.count({
      where: { artistId },
    });

    const totalAlbums = await this.albumRepository.count({
      where: { artistId },
    });

    const totalStreams = await this.songRepository
      .createQueryBuilder('song')
      .select('SUM(song.totalStreams)', 'total')
      .where('song.artistId = :artistId', { artistId })
      .getRawOne();

    return {
      artist,
      stats: {
        totalSongs,
        totalAlbums,
        totalStreams: parseInt(totalStreams.total) || 0,
        totalFollowers: artist.totalFollowers,
        monthlyListeners: artist.monthlyListeners,
      },
    };
  }

  async createArtist(data: {
    name: string;
    nationalityCode?: string;
    biography?: string;
    featured?: boolean;
    userId?: string;
    phone?: string;
    profileFile?: Express.Multer.File;
    coverFile?: Express.Multer.File;
  }): Promise<Artist> {
    const artist = new Artist();
    artist.name = data.name?.trim();
    artist.stageName = data.name?.trim(); // compatibilidad
    artist.nationalityCode = data.nationalityCode?.toUpperCase();
    artist.biography = data.biography;
    artist.isFeatured = !!data.featured;
    if (data.userId) {
      artist.userId = data.userId;
    }
    // Guardar teléfono solo para uso interno (admin/artista), en social_links
    if (data.phone) {
      artist.socialLinks = artist.socialLinks || {};
      (artist.socialLinks as any).phone = data.phone;
    }

    if (!data.profileFile || !data.coverFile) {
      throw new BadRequestException('Debe subir foto de perfil y portada para crear un artista');
    }

    if (data.profileFile) {
      const uploaded = await this.coversStorageService.uploadCoverImage(data.profileFile);
      artist.profilePhotoUrl = uploaded.url;
    }
    if (data.coverFile) {
      const uploaded = await this.coversStorageService.uploadCoverImage(data.coverFile);
      artist.coverPhotoUrl = uploaded.url;
    }

    return this.artistRepository.save(artist);
  }

  async updateArtist(
    id: string,
    data: {
      name?: string;
      nationalityCode?: string;
      biography?: string;
      featured?: boolean;
      phone?: string;
      profileFile?: Express.Multer.File;
      coverFile?: Express.Multer.File;
    },
  ): Promise<Artist> {
    const artist = await this.findOne(id);
    if (data.name) {
      artist.name = data.name.trim();
      artist.stageName = data.name.trim();
    }
    if (typeof data.featured === 'boolean') {
      artist.isFeatured = data.featured;
    }
    if (data.nationalityCode) {
      artist.nationalityCode = data.nationalityCode.toUpperCase();
    }
    if (data.biography !== undefined) {
      artist.biography = data.biography;
    }
    if (data.phone !== undefined) {
      artist.socialLinks = artist.socialLinks || {};
      (artist.socialLinks as any).phone = data.phone;
    }
    if (data.profileFile) {
      const uploaded = await this.coversStorageService.uploadCoverImage(data.profileFile);
      artist.profilePhotoUrl = uploaded.url;
    }
    if (data.coverFile) {
      const uploaded = await this.coversStorageService.uploadCoverImage(data.coverFile);
      artist.coverPhotoUrl = uploaded.url;
    }
    return this.artistRepository.save(artist);
  }

  /**
   * @deprecated Usar FeaturedService.setArtistFeatured() en su lugar (más eficiente)
   * Mantenido por compatibilidad con código existente
   */
  async toggleFeatured(id: string, featured: boolean): Promise<Artist> {
    // Delegar a FeaturedService para evitar duplicación y usar update() más eficiente
    if (this.featuredService) {
      return this.featuredService.setArtistFeatured(id, featured);
    }
    // Fallback si FeaturedService no está disponible
    const artist = await this.findOne(id);
    artist.isFeatured = featured;
    return this.artistRepository.save(artist);
  }

  async updateArtistProfile(artistId: string, updateData: any): Promise<Artist> {
    const artist = await this.findOne(artistId);
    
    Object.assign(artist, updateData);
    return this.artistRepository.save(artist);
  }

  /**
   * Mueve todas las canciones de un artista duplicado al artista correcto y elimina el duplicado
   * Solo para uso administrativo
   */
  async mergeDuplicateArtist(duplicateArtistId: string, correctArtistId: string): Promise<{ moved: number; deleted: boolean }> {
    const duplicateArtist = await this.findOne(duplicateArtistId);
    const correctArtist = await this.findOne(correctArtistId);

    // Mover todas las canciones del artista duplicado al artista correcto
    const songsToMove = await this.songRepository.find({
      where: [
        { artistId: duplicateArtistId },
      ],
    });

    let moved = 0;
    for (const song of songsToMove) {
      song.artistId = correctArtistId;
      await this.songRepository.save(song);
      moved++;
    }

    // Eliminar el artista duplicado
    await this.artistRepository.remove(duplicateArtist);

    return { moved, deleted: true };
  }

  async verifyArtist(artistId: string): Promise<Artist> {
    const artist = await this.findOne(artistId);
    artist.verificationStatus = true;
    return this.artistRepository.save(artist);
  }

  async getTopArtists(limit: number = 10): Promise<Artist[]> {
    return this.artistRepository.find({
      relations: ['user'],
      order: { totalStreams: 'DESC' },
      take: limit,
    });
  }

  async getVerifiedArtists(page: number = 1, limit: number = 10): Promise<{ artists: Artist[]; total: number }> {
    const [artists, total] = await this.artistRepository.findAndCount({
      where: { verificationStatus: true },
      relations: ['user'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return { artists, total };
  }

  async searchArtists(query: string, page: number = 1, limit: number = 10): Promise<{ artists: Artist[]; total: number }> {
    const [artists, total] = await this.artistRepository
      .createQueryBuilder('artist')
      .leftJoinAndSelect('artist.user', 'user')
      .where('(artist.stageName ILIKE :query OR artist.name ILIKE :query)', { query: `%${query}%` })
      .skip((page - 1) * limit)
      .take(limit)
      .orderBy('artist.createdAt', 'DESC')
      .getManyAndCount();

    return { artists, total };
  }

  async deleteArtist(id: string): Promise<void> {
    const artist = await this.findOne(id);
    
    // Verificar si el artista tiene canciones asociadas
    const songsCount = await this.songRepository.count({ where: { artistId: id } });
    if (songsCount > 0) {
      throw new BadRequestException(
        `No se puede eliminar el artista porque tiene ${songsCount} ${songsCount === 1 ? 'canción' : 'canciones'} asociadas. ` +
        'Por favor, elimina o reasigna las canciones antes de eliminar el artista.'
      );
    }

    // Verificar si el artista tiene álbumes asociados
    const albumsCount = await this.albumRepository.count({ where: { artistId: id } });
    if (albumsCount > 0) {
      throw new BadRequestException(
        `No se puede eliminar el artista porque tiene ${albumsCount} ${albumsCount === 1 ? 'álbum' : 'álbumes'} asociados. ` +
        'Por favor, elimina o reasigna los álbumes antes de eliminar el artista.'
      );
    }

    await this.artistRepository.remove(artist);
  }
}




