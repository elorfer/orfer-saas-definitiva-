import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from './user.entity';
import { Song } from './song.entity';

@Entity('play_history')
export class PlayHistory {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ name: 'song_id' })
  songId: string;

  @CreateDateColumn({ name: 'played_at' })
  playedAt: Date;

  @Column({ name: 'duration_played', nullable: true })
  durationPlayed?: number; // duración reproducida en segundos

  @Column({ default: false })
  completed: boolean;

  // Relaciones
  @ManyToOne(() => User, (user) => user.playHistory, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @ManyToOne(() => Song, (song) => song.playHistory, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'song_id' })
  song: Song;

  // Métodos de utilidad
  get completionPercentage(): number {
    if (!this.durationPlayed || !this.song) {
      return 0;
    }
    return Math.min(100, (this.durationPlayed / this.song.duration) * 100);
  }

  isCompleted(): boolean {
    return this.completed || this.completionPercentage >= 90;
  }
}









