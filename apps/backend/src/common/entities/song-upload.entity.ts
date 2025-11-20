import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

export enum UploadStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  COMPLETED = 'completed',
  FAILED = 'failed',
  CANCELLED = 'cancelled',
}

@Entity('song_uploads')
@Index(['uploadId'], { unique: true })
@Index(['userId', 'status'])
@Index(['createdAt'])
export class SongUpload {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'upload_id', unique: true })
  uploadId: string; // ID único para idempotencia (generado por cliente o servidor)

  @Column({ name: 'user_id' })
  userId: string;

  @Column({
    type: 'enum',
    enum: UploadStatus,
    default: UploadStatus.PENDING,
  })
  status: UploadStatus;

  @Column({ name: 'audio_file_key', nullable: true })
  audioFileKey?: string; // Clave del archivo de audio subido

  @Column({ name: 'cover_file_key', nullable: true })
  coverFileKey?: string; // Clave del archivo de portada subido

  @Column({ name: 'song_id', nullable: true })
  songId?: string; // ID de la canción creada (si se completó)

  @Column({ type: 'text', nullable: true })
  title?: string;

  @Column({ name: 'artist_id', nullable: true })
  artistId?: string;

  @Column({ name: 'album_id', nullable: true })
  albumId?: string;

  @Column({ name: 'genre_id', nullable: true })
  genreId?: string;

  @Column({ type: 'text', nullable: true })
  error?: string; // Mensaje de error si falló

  @Column({ type: 'jsonb', nullable: true })
  metadata?: {
    duration?: number;
    bitrate?: number;
    codec?: string;
    sampleRate?: number;
    channels?: number;
    format?: string;
    title?: string;
    artist?: string;
    album?: string;
  };

  @Column({ name: 'job_id', nullable: true })
  jobId?: string; // ID del job de BullMQ

  @Column({ name: 'retry_count', default: 0 })
  retryCount: number;

  @Column({ name: 'compensation_applied', default: false })
  compensationApplied: boolean; // Si se aplicó limpieza de archivos

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}







