import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { AudioAd } from './audio-ad.entity';

@Entity('ad_play_logs')
export class AdPlayLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'ad_id' })
  adId: string;

  @Column({ name: 'user_id', nullable: true })
  userId?: string; // null si es usuario anónimo

  @Column({ name: 'played_at', type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  playedAt: Date;

  @Column({ name: 'duration_played', type: 'int' })
  durationPlayed: number; // Segundos realmente reproducidos

  @Column({ name: 'was_completed', default: false })
  wasCompleted: boolean; // Si se reprodujo completo

  @Column({ name: 'was_skipped', default: false })
  wasSkipped: boolean; // Si fue saltado

  @Column({ name: 'was_clicked', default: false })
  wasClicked: boolean; // Si se hizo click

  @Column({ name: 'context_genre', nullable: true })
  contextGenre?: string; // Género de la canción que precedió

  @Column({ name: 'context_artist', nullable: true })
  contextArtist?: string; // Artista de la canción que precedió

  @Column({ name: 'context_playlist_id', nullable: true })
  contextPlaylistId?: string; // ID de playlist si aplica

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  // Relaciones
  @ManyToOne(() => AudioAd, (ad) => ad.playLogs, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'ad_id' })
  ad: AudioAd;
}

