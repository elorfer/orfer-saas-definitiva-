import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToOne,
  OneToMany,
  ManyToMany,
  JoinTable,
} from 'typeorm';
import { Artist } from './artist.entity';
import { Playlist } from './playlist.entity';
import { PlayHistory } from './play-history.entity';
import { SongLike } from './song-like.entity';
import { Payment } from './payment.entity';

export enum UserRole {
  ADMIN = 'admin',
  ARTIST = 'artist',
  USER = 'user',
}

export enum SubscriptionStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  CANCELLED = 'cancelled',
  EXPIRED = 'expired',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column({ unique: true, length: 50 })
  username: string;

  @Column({ name: 'password_hash' })
  passwordHash: string;

  @Column({ name: 'first_name', length: 100 })
  firstName: string;

  @Column({ name: 'last_name', length: 100 })
  lastName: string;

  @Column({ name: 'avatar_url', nullable: true })
  avatarUrl?: string;

  @Column({
    type: 'enum',
    enum: UserRole,
    default: UserRole.USER,
  })
  role: UserRole;

  @Column({
    name: 'subscription_status',
    type: 'enum',
    enum: SubscriptionStatus,
    default: SubscriptionStatus.INACTIVE,
  })
  subscriptionStatus: SubscriptionStatus;

  @Column({ name: 'subscription_expires_at', nullable: true })
  subscriptionExpiresAt?: Date;

  @Column({ name: 'is_verified', default: false })
  isVerified: boolean;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ name: 'last_login_at', nullable: true })
  lastLoginAt?: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relaciones
  @OneToOne(() => Artist, (artist) => artist.user)
  artist?: Artist;

  @OneToMany(() => Playlist, (playlist) => playlist.user)
  playlists: Playlist[];

  @OneToMany(() => PlayHistory, (playHistory) => playHistory.user)
  playHistory: PlayHistory[];

  @OneToMany(() => SongLike, (songLike) => songLike.user)
  songLikes: SongLike[];

  @OneToMany(() => Payment, (payment) => payment.user)
  payments: Payment[];

  // Métodos de utilidad
  get fullName(): string {
    return `${this.firstName} ${this.lastName}`;
  }

  isAdmin(): boolean {
    return this.role === UserRole.ADMIN;
  }

  isArtist(): boolean {
    return this.role === UserRole.ARTIST;
  }

  isUser(): boolean {
    return this.role === UserRole.USER;
  }

  hasActiveSubscription(): boolean {
    return (
      this.subscriptionStatus === SubscriptionStatus.ACTIVE &&
      this.subscriptionExpiresAt &&
      this.subscriptionExpiresAt > new Date()
    );
  }
}









