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

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  // Relaciones
  @OneToMany(() => Song, (song) => song.genre)
  songs: Song[];

  @OneToMany(() => Album, (album) => album.genre)
  albums: Album[];

  // Métodos de utilidad
  get displayColor(): string {
    return this.colorHex || '#6B7280';
  }

  get songCount(): number {
    return this.songs?.length || 0;
  }

  get albumCount(): number {
    return this.albums?.length || 0;
  }
}









