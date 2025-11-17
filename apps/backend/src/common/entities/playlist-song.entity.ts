import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Playlist } from './playlist.entity';
import { Song } from './song.entity';

@Entity('playlist_songs')
@Unique(['playlistId', 'songId'])
export class PlaylistSong {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'playlist_id' })
  playlistId: string;

  @Column({ name: 'song_id' })
  songId: string;

  @Column({ type: 'int' })
  position: number;

  @CreateDateColumn({ name: 'added_at' })
  addedAt: Date;

  // Relaciones
  @ManyToOne(() => Playlist, (playlist) => playlist.playlistSongs, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'playlist_id' })
  playlist: Playlist;

  @ManyToOne(() => Song, (song) => song.playlistSongs, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'song_id' })
  song: Song;
}









