import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { AdPlayLog } from './ad-play-log.entity';

export enum AdStatus {
  DRAFT = 'draft',
  ACTIVE = 'active',
  PAUSED = 'paused',
  EXPIRED = 'expired',
}

export enum AdTargeting {
  ALL = 'all',
  GENRE = 'genre',
  ARTIST = 'artist',
  PLAYLIST = 'playlist',
}

@Entity('audio_ads')
export class AudioAd {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ name: 'audio_url', nullable: true })
  audioUrl?: string; // URL del archivo de audio (MP3, AAC, etc.) - Opcional al crear, se actualiza después de subir archivo

  @Column({ name: 'cover_image_url', nullable: true })
  coverImageUrl?: string; // URL de la carátula

  @Column({ name: 'advertiser_name', length: 100 })
  advertiserName: string; // Nombre del anunciante

  @Column({ name: 'click_through_url', nullable: true })
  clickThroughUrl?: string; // URL a abrir al hacer click

  @Column({ name: 'duration_seconds', type: 'int' })
  durationSeconds: number; // Duración en segundos

  @Column({ name: 'file_size_bytes', type: 'bigint' })
  fileSizeBytes: number; // Tamaño del archivo

  @Column({
    type: 'enum',
    enum: AdStatus,
    default: AdStatus.DRAFT,
  })
  status: AdStatus; // DRAFT, ACTIVE, PAUSED, EXPIRED

  @Column({
    type: 'enum',
    enum: AdTargeting,
    default: AdTargeting.ALL,
  })
  targeting: AdTargeting; // ALL, GENRE, ARTIST, PLAYLIST

  @Column({ name: 'target_genres', type: 'json', nullable: true })
  targetGenres?: string[]; // Si targeting es GENRE

  @Column({ name: 'target_artists', type: 'json', nullable: true })
  targetArtists?: string[]; // Si targeting es ARTIST

  @Column({ name: 'target_playlists', type: 'json', nullable: true })
  targetPlaylists?: string[]; // Si targeting es PLAYLIST

  @Column({ name: 'frequency_per_hour', type: 'int', default: 1 })
  frequencyPerHour: number; // Máximo de veces por hora

  @Column({ name: 'max_plays_per_day', type: 'int', nullable: true })
  maxPlaysPerDay?: number; // Límite diario (opcional)

  @Column({ name: 'start_date', type: 'timestamp', nullable: true })
  startDate?: Date; // Fecha de inicio de campaña

  @Column({ name: 'end_date', type: 'timestamp', nullable: true })
  endDate?: Date; // Fecha de fin de campaña

  @Column({ name: 'priority', type: 'int', default: 0 })
  priority: number; // Mayor = más prioridad (0-100)

  @Column({ name: 'is_skippable', default: true })
  isSkippable: boolean; // Si el usuario puede saltar después de X segundos

  @Column({ name: 'skip_after_seconds', type: 'int', default: 5 })
  skipAfterSeconds: number; // Segundos antes de permitir skip

  @Column({ name: 'total_plays', type: 'int', default: 0 })
  totalPlays: number; // Contador de reproducciones

  @Column({ name: 'total_clicks', type: 'int', default: 0 })
  totalClicks: number; // Contador de clicks

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relaciones
  @OneToMany(() => AdPlayLog, (log) => log.ad)
  playLogs: AdPlayLog[];

  // Métodos de utilidad
  isActive(): boolean {
    const now = new Date();
    return (
      this.status === AdStatus.ACTIVE &&
      (!this.startDate || this.startDate <= now) &&
      (!this.endDate || this.endDate >= now)
    );
  }

  matchesTargeting(context?: {
    genre?: string;
    artist?: string;
    playlistId?: string;
  }): boolean {
    if (this.targeting === AdTargeting.ALL) {
      return true;
    }

    if (!context) {
      return false;
    }

    if (this.targeting === AdTargeting.GENRE && context.genre) {
      return this.targetGenres?.includes(context.genre) ?? false;
    }

    if (this.targeting === AdTargeting.ARTIST && context.artist) {
      return this.targetArtists?.includes(context.artist) ?? false;
    }

    if (this.targeting === AdTargeting.PLAYLIST && context.playlistId) {
      return this.targetPlaylists?.includes(context.playlistId) ?? false;
    }

    return false;
  }
}

