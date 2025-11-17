import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from './user.entity';

export enum PaymentStatus {
  PENDING = 'pending',
  COMPLETED = 'completed',
  FAILED = 'failed',
  REFUNDED = 'refunded',
}

export enum PaymentMethod {
  STRIPE = 'stripe',
  PAYPAL = 'paypal',
}

@Entity('payments')
export class Payment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  amount: number;

  @Column({ length: 3, default: 'USD' })
  currency: string;

  @Column({ name: 'payment_method', length: 50 })
  paymentMethod: PaymentMethod;

  @Column({ name: 'payment_intent_id', nullable: true })
  paymentIntentId?: string;

  @Column({
    type: 'enum',
    enum: PaymentStatus,
    default: PaymentStatus.PENDING,
  })
  status: PaymentStatus;

  @Column({ name: 'subscription_period_start', nullable: true })
  subscriptionPeriodStart?: Date;

  @Column({ name: 'subscription_period_end', nullable: true })
  subscriptionPeriodEnd?: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relaciones
  @ManyToOne(() => User, (user) => user.payments, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  // Métodos de utilidad
  isCompleted(): boolean {
    return this.status === PaymentStatus.COMPLETED;
  }

  isPending(): boolean {
    return this.status === PaymentStatus.PENDING;
  }

  isFailed(): boolean {
    return this.status === PaymentStatus.FAILED;
  }

  isRefunded(): boolean {
    return this.status === PaymentStatus.REFUNDED;
  }

  get amountFormatted(): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: this.currency,
    }).format(this.amount);
  }

  isSubscriptionPayment(): boolean {
    return !!(this.subscriptionPeriodStart && this.subscriptionPeriodEnd);
  }

  get subscriptionDuration(): number | null {
    if (!this.subscriptionPeriodStart || !this.subscriptionPeriodEnd) {
      return null;
    }
    return Math.ceil(
      (this.subscriptionPeriodEnd.getTime() - this.subscriptionPeriodStart.getTime()) / (1000 * 60 * 60 * 24)
    );
  }
}
