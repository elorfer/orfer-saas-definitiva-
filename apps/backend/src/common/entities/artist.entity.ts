import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToOne,
  OneToMany,
  ManyToMany,
  JoinColumn,
  JoinTable,
} from 'typeorm';
import { User } from './user.entity';
import { Song } from './song.entity';
import { Album } from './album.entity';
import { ArtistFollower } from './artist-follower.entity';

@Entity('artists')
export class Artist {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  // Nuevo modelo principal
  @Column({ name: 'name', length: 150, nullable: true })
  name?: string;

  @Column({ name: 'profile_photo_url', type: 'text', nullable: true })
  profilePhotoUrl?: string;

  @Column({ name: 'cover_photo_url', type: 'text', nullable: true })
  coverPhotoUrl?: string;

  @Column({ name: 'nationality_code', type: 'char', length: 2, nullable: true })
  nationalityCode?: string;

  @Column({ name: 'biography', type: 'text', nullable: true })
  biography?: string;

  @Column({ name: 'featured', type: 'boolean', default: false })
  featured: boolean;

  @Column({ name: 'user_id', nullable: true })
  userId: string;

  @Column({ name: 'stage_name', length: 100 })
  stageName: string;

  @Column({ type: 'text', nullable: true })
  bio?: string;

  @Column({ name: 'website_url', nullable: true })
  websiteUrl?: string;

  @Column({ name: 'social_links', type: 'jsonb', default: {} })
  socialLinks: Record<string, string>;

  @Column({ name: 'verification_status', default: false })
  verificationStatus: boolean;

  @Column({ name: 'total_streams', default: 0 })
  totalStreams: number;

  @Column({ name: 'total_followers', default: 0 })
  totalFollowers: number;

  @Column({ name: 'monthly_listeners', default: 0 })
  monthlyListeners: number;

  @Column({ name: 'is_featured', default: false })
  isFeatured: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relaciones
  @OneToOne(() => User, (user) => user.artist)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @OneToMany(() => Song, (song) => song.artist)
  songs: Song[];

  @OneToMany(() => Album, (album) => album.artist)
  albums: Album[];

  @OneToMany(() => ArtistFollower, (follower) => follower.artist)
  followers: ArtistFollower[];

  // Métodos de utilidad
  get displayName(): string {
    return this.stageName;
  }

  isVerified(): boolean {
    return this.verificationStatus;
  }

  getSocialLink(platform: string): string | undefined {
    return this.socialLinks[platform];
  }

  addSocialLink(platform: string, url: string): void {
    this.socialLinks[platform] = url;
  }

  removeSocialLink(platform: string): void {
    delete this.socialLinks[platform];
  }
}









