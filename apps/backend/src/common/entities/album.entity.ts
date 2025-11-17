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
import { Genre } from './genre.entity';
import { Song } from './song.entity';

@Entity('albums')
export class Album {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'artist_id' })
  artistId: string;

  @Column({ length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ name: 'cover_art_url', nullable: true })
  coverArtUrl?: string;

  @Column({ name: 'release_date', nullable: true })
  releaseDate?: Date;

  @Column({ name: 'genre_id', nullable: true })
  genreId?: string;

  @Column({ name: 'total_tracks', default: 0 })
  totalTracks: number;

  @Column({ name: 'total_duration', default: 0 })
  totalDuration: number; // en segundos

  @Column({ name: 'is_single', default: false })
  isSingle: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relaciones
  @ManyToOne(() => Artist, (artist) => artist.albums)
  @JoinColumn({ name: 'artist_id' })
  artist: Artist;

  @ManyToOne(() => Genre, (genre) => genre.albums)
  @JoinColumn({ name: 'genre_id' })
  genre?: Genre;

  @OneToMany(() => Song, (song) => song.album)
  songs: Song[];

  // Métodos de utilidad
  get durationFormatted(): string {
    const hours = Math.floor(this.totalDuration / 3600);
    const minutes = Math.floor((this.totalDuration % 3600) / 60);
    const seconds = this.totalDuration % 60;

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }

  updateTrackCount(): void {
    this.totalTracks = this.songs?.length || 0;
  }

  updateTotalDuration(): void {
    this.totalDuration = this.songs?.reduce((total, song) => total + song.duration, 0) || 0;
  }

  isEP(): boolean {
    return this.totalTracks >= 3 && this.totalTracks <= 6;
  }

  isLP(): boolean {
    return this.totalTracks >= 7;
  }
}









