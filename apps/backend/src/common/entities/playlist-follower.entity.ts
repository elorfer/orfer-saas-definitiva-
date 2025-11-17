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
import { User } from './user.entity';

@Entity('playlist_followers')
@Unique(['playlistId', 'userId'])
export class PlaylistFollower {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'playlist_id' })
  playlistId: string;

  @Column({ name: 'user_id' })
  userId: string;

  @CreateDateColumn({ name: 'followed_at' })
  followedAt: Date;

  // Relaciones
  @ManyToOne(() => Playlist, (playlist) => playlist.followers, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'playlist_id' })
  playlist: Playlist;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
}









