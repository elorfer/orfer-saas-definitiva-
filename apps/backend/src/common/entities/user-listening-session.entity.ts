import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
  Unique,
} from 'typeorm';
import { User } from './user.entity';
import { Song } from './song.entity';

@Entity('user_listening_sessions')
@Unique(['userId', 'songId'])
@Index(['userId', 'songId'])
@Index(['createdAt'])
export class UserListeningSession {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ name: 'song_id' })
  songId: string;

  @Column({ name: 'max_progress_ms', type: 'bigint', default: 0 })
  maxProgressMs: number; // Máximo progreso alcanzado en milisegundos

  @Column({ name: 'started_at', type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  startedAt: Date;

  @Column({ name: 'last_progress_update', type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  lastProgressUpdate: Date;

  @Column({ name: 'is_stream_validated', type: 'boolean', default: false })
  isStreamValidated: boolean; // Si ya se registró como stream válido

  @Column({ name: 'stream_validated_at', type: 'timestamp', nullable: true })
  streamValidatedAt: Date | null;

  @Column({ name: 'is_paused', type: 'boolean', default: false })
  isPaused: boolean;

  @Column({ name: 'pause_count', type: 'int', default: 0 })
  pauseCount: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relaciones
  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @ManyToOne(() => Song, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'song_id' })
  song: Song;
}












