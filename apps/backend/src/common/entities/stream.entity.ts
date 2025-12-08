import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from './user.entity';
import { Song } from './song.entity';

@Entity('streams')
@Index(['userId', 'songId', 'createdAt'])
@Index(['songId', 'createdAt'])
@Index(['userId', 'createdAt'])
export class Stream {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ name: 'song_id' })
  songId: string;

  @Column({ name: 'duration_listened', type: 'int', default: 0 })
  durationListened: number; // en segundos

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  // Relaciones
  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @ManyToOne(() => Song, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'song_id' })
  song: Song;
}






