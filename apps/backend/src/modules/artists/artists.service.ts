import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Artist } from '../../common/entities/artist.entity';
import { User } from '../../common/entities/user.entity';
import { Song } from '../../common/entities/song.entity';
import { Album } from '../../common/entities/album.entity';
import { CoversStorageService } from '../covers/covers-storage.service';

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

  async findFeatured(limit: number = 20): Promise<Artist[]> {
    return this.artistRepository.find({
      where: { isFeatured: true },
      order: { createdAt: 'DESC' },
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

  async toggleFeatured(id: string, featured: boolean): Promise<Artist> {
    const artist = await this.findOne(id);
    if (featured && (!artist.profilePhotoUrl || !artist.coverPhotoUrl)) {
      throw new BadRequestException('Para destacar un artista, debe tener foto de perfil y portada cargadas');
    }
    artist.isFeatured = featured;
    return this.artistRepository.save(artist);
  }

  async updateArtistProfile(artistId: string, updateData: any): Promise<Artist> {
    const artist = await this.findOne(artistId);
    
    Object.assign(artist, updateData);
    return this.artistRepository.save(artist);
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
}









