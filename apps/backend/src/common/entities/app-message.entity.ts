import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

export enum AppMessageType {
  HOME_BANNER = 'HOME_BANNER',
}

@Entity('app_messages')
export class AppMessage {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({
    type: 'enum',
    enum: AppMessageType,
    default: AppMessageType.HOME_BANNER,
  })
  @Index('idx_app_messages_type')
  type: AppMessageType;

  @Column({ type: 'text' })
  message: string;

  @Column({ name: 'is_active', type: 'boolean', default: true })
  @Index('idx_app_messages_active')
  isActive: boolean;

  @Column({ name: 'created_by', type: 'uuid', nullable: true })
  createdBy?: string;

  @Column({
    name: 'published_at',
    type: 'timestamptz',
    default: () => 'CURRENT_TIMESTAMP',
  })
  @Index('idx_app_messages_published_at')
  publishedAt: Date;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}







