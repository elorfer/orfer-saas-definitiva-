import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
    UpdateDateColumn,
    ManyToOne,
    JoinColumn,
    Index,
} from 'typeorm';
import { User } from './user.entity';

export enum AffinityEntityType {
    ARTIST = 'artist',
    GENRE = 'genre',
}

@Entity('user_affinities')
@Index(['userId', 'entityId', 'entityType'], { unique: true }) // Ensure unique score per user-entity pair
export class UserAffinity {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ name: 'user_id' })
    userId: string;

    @Column({ name: 'entity_id' })
    entityId: string;

    @Column({
        type: 'enum',
        enum: AffinityEntityType,
        name: 'entity_type',
    })
    entityType: AffinityEntityType;

    @Column({ type: 'float', default: 0 })
    score: number;

    @Column({ name: 'interaction_count', default: 0 })
    interactionCount: number;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;

    // Relations
    @ManyToOne(() => User, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'user_id' })
    user: User;
}
