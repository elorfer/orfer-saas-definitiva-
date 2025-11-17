import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Artist } from './artist.entity';
import { User } from './user.entity';

@Entity('artist_followers')
@Unique(['artistId', 'userId'])
export class ArtistFollower {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'artist_id' })
  artistId: string;

  @Column({ name: 'user_id' })
  userId: string;

  @CreateDateColumn({ name: 'followed_at' })
  followedAt: Date;

  // Relaciones
  @ManyToOne(() => Artist, (artist) => artist.followers, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'artist_id' })
  artist: Artist;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
}









