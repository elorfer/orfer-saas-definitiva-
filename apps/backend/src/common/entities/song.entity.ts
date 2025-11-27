import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { Artist } from './artist.entity';
import { Album } from './album.entity';
import { Genre } from './genre.entity';
import { PlaylistSong } from './playlist-song.entity';
import { SongLike } from './song-like.entity';
import { PlayHistory } from './play-history.entity';
import { StreamingStats } from './streaming-stats.entity';

export enum SongStatus {
  DRAFT = 'draft',
  PUBLISHED = 'published',
  ARCHIVED = 'archived',
}

@Entity('songs')
export class Song {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'artist_id' })
  artistId: string;

  @Column({ name: 'album_id', nullable: true })
  albumId?: string;

  @Column({ length: 200 })
  title: string;

  @Column({ type: 'int' })
  duration: number; // en segundos

  @Column({ name: 'file_url' })
  fileUrl: string; // URL del archivo HLS

  @Column({ name: 'cover_art_url', nullable: true })
  coverArtUrl?: string;

  @Column({ type: 'text', nullable: true })
  lyrics?: string;

  @Column({ name: 'genre_id', nullable: true })
  genreId?: string;

  @Column({ type: 'simple-array', nullable: true, name: 'genres' })
  genres?: string[]; // Array de géneros musicales (ej: ["Reggaeton", "Trap Latino"])

  @Column({ name: 'track_number', nullable: true })
  trackNumber?: number;

  @Column({
    type: 'enum',
    enum: SongStatus,
    default: SongStatus.DRAFT,
  })
  status: SongStatus;

  @Column({ name: 'is_explicit', default: false })
  isExplicit: boolean;

  @Column({ name: 'release_date', nullable: true })
  releaseDate?: Date;

  @Column({ name: 'total_streams', default: 0 })
  totalStreams: number;

  @Column({ name: 'total_likes', default: 0 })
  totalLikes: number;

  @Column({ name: 'total_shares', default: 0 })
  totalShares: number;

  @Column({ name: 'is_featured', default: false })
  isFeatured: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relaciones
  @ManyToOne(() => Artist, (artist) => artist.songs)
  @JoinColumn({ name: 'artist_id' })
  artist: Artist;

  @ManyToOne(() => Album, (album) => album.songs)
  @JoinColumn({ name: 'album_id' })
  album?: Album;

  @ManyToOne(() => Genre, (genre) => genre.songs)
  @JoinColumn({ name: 'genre_id' })
  genre?: Genre;

  @OneToMany(() => PlaylistSong, (playlistSong) => playlistSong.song)
  playlistSongs: PlaylistSong[];

  @OneToMany(() => SongLike, (songLike) => songLike.song)
  likes: SongLike[];

  @OneToMany(() => PlayHistory, (playHistory) => playHistory.song)
  playHistory: PlayHistory[];

  @OneToMany(() => StreamingStats, (stats) => stats.song)
  streamingStats: StreamingStats[];

  // Métodos de utilidad
  get durationFormatted(): string {
    const minutes = Math.floor(this.duration / 60);
    const seconds = this.duration % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }

  isPublished(): boolean {
    return this.status === SongStatus.PUBLISHED;
  }

  isDraft(): boolean {
    return this.status === SongStatus.DRAFT;
  }

  isArchived(): boolean {
    return this.status === SongStatus.ARCHIVED;
  }

  incrementStreams(): void {
    this.totalStreams += 1;
  }

  incrementLikes(): void {
    this.totalLikes += 1;
  }

  decrementLikes(): void {
    this.totalLikes = Math.max(0, this.totalLikes - 1);
  }

  incrementShares(): void {
    this.totalShares += 1;
  }
}









