import {
    Entity,
    Column,
    PrimaryGeneratedColumn,
    CreateDateColumn,
    UpdateDateColumn,
    ManyToOne,
    JoinColumn,
} from 'typeorm';
import { User } from './user.entity';

export enum UploadStatus {
    PENDING = 'pending',
    COMPLETED = 'completed',
    FAILED = 'failed',
    EXPIRED = 'expired',
}

@Entity('uploads')
export class Upload {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ name: 'user_id' })
    userId: string;

    @ManyToOne(() => User)
    @JoinColumn({ name: 'user_id' })
    user: User;

    @Column({ name: 'object_key' })
    objectKey: string;

    @Column({ name: 'content_type' })
    contentType: string;

    @Column({ name: 'expected_size', nullable: true })
    expectedSize: number;

    @Column({
        type: 'enum',
        enum: UploadStatus,
        default: UploadStatus.PENDING,
    })
    status: UploadStatus;

    @Column({ name: 'expires_at' })
    expiresAt: Date;

    @Column({ name: 'client_ip', nullable: true })
    clientIp: string;

    @Column({ name: 'user_agent', nullable: true })
    userAgent: string;

    @Column({ name: 'actual_size', nullable: true })
    actualSize: number;

    @Column({ name: 'completed_at', nullable: true })
    completedAt: Date;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;
}
