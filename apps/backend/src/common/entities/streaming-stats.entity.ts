import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Song } from './song.entity';

@Entity('streaming_stats')
@Unique(['songId', 'date'])
export class StreamingStats {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'song_id' })
  songId: string;

  @Column({ type: 'date' })
  date: Date;

  @Column({ name: 'total_streams', default: 0 })
  totalStreams: number;

  @Column({ name: 'unique_listeners', default: 0 })
  uniqueListeners: number;

  @Column({ name: 'total_duration', default: 0 })
  totalDuration: number; // duración total reproducida en segundos

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relaciones
  @ManyToOne(() => Song, (song) => song.streamingStats, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'song_id' })
  song: Song;

  // Métodos de utilidad
  get averageListenDuration(): number {
    if (this.totalStreams === 0) return 0;
    return this.totalDuration / this.totalStreams;
  }

  get averageListenDurationFormatted(): string {
    const avgDuration = this.averageListenDuration;
    const minutes = Math.floor(avgDuration / 60);
    const seconds = Math.floor(avgDuration % 60);
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }

  incrementStreams(): void {
    this.totalStreams += 1;
  }

  incrementUniqueListeners(): void {
    this.uniqueListeners += 1;
  }

  addDuration(duration: number): void {
    this.totalDuration += duration;
  }
}









