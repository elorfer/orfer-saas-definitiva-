import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Song } from './song.entity';
import { User } from './user.entity';

@Entity('song_likes')
@Unique(['songId', 'userId'])
export class SongLike {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'song_id' })
  songId: string;

  @Column({ name: 'user_id' })
  userId: string;

  @CreateDateColumn({ name: 'liked_at' })
  likedAt: Date;

  // Relaciones
  @ManyToOne(() => Song, (song) => song.likes, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'song_id' })
  song: Song;

  @ManyToOne(() => User, (user) => user.songLikes, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
}









