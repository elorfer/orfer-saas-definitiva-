import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  OneToMany,
} from 'typeorm';
import { Song } from './song.entity';
import { Album } from './album.entity';

@Entity('genres')
export class Genre {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, length: 50 })
  name: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ name: 'color_hex', length: 7, nullable: true })
  colorHex?: string;

  @Column({ name: 'image_url', type: 'text', nullable: true })
  imageUrl?: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  // Relaciones
  @OneToMany(() =\u003e Song, (song) =\u003e song.genre)
  songs: Song[];

  @OneToMany(() =\u003e Album, (album) =\u003e album.genre)
  albums: Album[];

  // Contadores - Propiedades normales (no getters) para permitir loadRelationCountAndMap
  songCount?: number;
  albumCount?: number;

  // Métodos de utilidad
  get displayColor(): string {
    return this.colorHex || '#6B7280';
  }
}
