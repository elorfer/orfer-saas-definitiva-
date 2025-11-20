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
import { User } from './user.entity';
import { PlaylistSong } from './playlist-song.entity';
import { PlaylistFollower } from './playlist-follower.entity';

export enum PlaylistVisibility {
  PUBLIC = 'public',
  PRIVATE = 'private',
  UNLISTED = 'unlisted',
}

@Entity('playlists')
export class Playlist {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ length: 200 })
  name: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ name: 'cover_art_url', nullable: true })
  coverArtUrl?: string;

  @Column({
    type: 'enum',
    enum: PlaylistVisibility,
    default: PlaylistVisibility.PUBLIC,
  })
  visibility: PlaylistVisibility;

  @Column({ name: 'total_tracks', default: 0 })
  totalTracks: number;

  @Column({ name: 'total_duration', default: 0 })
  totalDuration: number; // en segundos

  @Column({ name: 'total_followers', default: 0 })
  totalFollowers: number;

  @Column({ name: 'is_featured', default: false })
  isFeatured: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relaciones
  @ManyToOne(() => User, (user) => user.playlists)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @OneToMany(() => PlaylistSong, (playlistSong) => playlistSong.playlist)
  playlistSongs: PlaylistSong[];

  @OneToMany(() => PlaylistFollower, (follower) => follower.playlist)
  followers: PlaylistFollower[];

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

  isPublic(): boolean {
    return this.visibility === PlaylistVisibility.PUBLIC;
  }

  isPrivate(): boolean {
    return this.visibility === PlaylistVisibility.PRIVATE;
  }

  isUnlisted(): boolean {
    return this.visibility === PlaylistVisibility.UNLISTED;
  }

  updateTrackCount(): void {
    // Filtrar solo canciones válidas y publicadas
    const validSongs = this.playlistSongs?.filter(
      (ps) => ps.song != null && ps.song.status === 'published'
    ) || [];
    this.totalTracks = validSongs.length;
  }

  updateTotalDuration(): void {
    // Filtrar solo canciones válidas y publicadas para calcular la duración
    const validSongs = this.playlistSongs?.filter(
      (ps) => ps.song != null && ps.song.status === 'published' && ps.song.duration != null
    ) || [];
    
    this.totalDuration = validSongs.reduce(
      (total, playlistSong) => total + (playlistSong.song?.duration || 0),
      0
    );
  }

  getSongs(): any[] {
    return this.playlistSongs
      ?.filter((ps) => ps.song != null && ps.song.status === 'published')
      .sort((a, b) => a.position - b.position)
      .map(playlistSong => playlistSong.song) || [];
  }
}









