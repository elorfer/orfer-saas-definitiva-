import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import Stripe from 'stripe';

import { Payment, PaymentStatus, PaymentMethod } from '../../common/entities/payment.entity';
import { User } from '../../common/entities/user.entity';
import { SubscriptionStatus } from '../../common/entities/user.entity';

@Injectable()
export class PaymentsService {
  private stripe: Stripe;

  constructor(
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {
    this.stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
      apiVersion: '2023-10-16',
    });
  }

  async createPaymentIntent(userId: string, amount: number, currency: string = 'USD'): Promise<any> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Usuario no encontrado');
    }

    try {
      const paymentIntent = await this.stripe.paymentIntents.create({
        amount: Math.round(amount * 100), // Convertir a centavos
        currency,
        metadata: {
          userId,
        },
      });

      // Guardar en base de datos
      const payment = this.paymentRepository.create({
        userId,
        amount,
        currency,
        paymentMethod: PaymentMethod.STRIPE,
        paymentIntentId: paymentIntent.id,
        status: PaymentStatus.PENDING,
      });

      await this.paymentRepository.save(payment);

      return {
        clientSecret: paymentIntent.client_secret,
        paymentId: payment.id,
      };
    } catch (error) {
      throw new BadRequestException(`Error al crear payment intent: ${error.message}`);
    }
  }

  async confirmPayment(paymentId: string): Promise<Payment> {
    const payment = await this.paymentRepository.findOne({ where: { id: paymentId } });
    if (!payment) {
      throw new NotFoundException('Pago no encontrado');
    }

    try {
      const paymentIntent = await this.stripe.paymentIntents.retrieve(payment.paymentIntentId);

      if (paymentIntent.status === 'succeeded') {
        payment.status = PaymentStatus.COMPLETED;
        
        // Activar suscripción del usuario
        const user = await this.userRepository.findOne({ where: { id: payment.userId } });
        if (user) {
          user.subscriptionStatus = SubscriptionStatus.ACTIVE;
          user.subscriptionExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 días
          await this.userRepository.save(user);
        }

        await this.paymentRepository.save(payment);
      } else {
        payment.status = PaymentStatus.FAILED;
        await this.paymentRepository.save(payment);
      }

      return payment;
    } catch (error) {
      throw new BadRequestException(`Error al confirmar pago: ${error.message}`);
    }
  }

  async getUserPayments(userId: string): Promise<Payment[]> {
    return this.paymentRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
    });
  }

  async getPaymentById(paymentId: string): Promise<Payment> {
    const payment = await this.paymentRepository.findOne({ where: { id: paymentId } });
    if (!payment) {
      throw new NotFoundException('Pago no encontrado');
    }
    return payment;
  }

  async refundPayment(paymentId: string): Promise<Payment> {
    const payment = await this.paymentRepository.findOne({ where: { id: paymentId } });
    if (!payment) {
      throw new NotFoundException('Pago no encontrado');
    }

    if (payment.status !== PaymentStatus.COMPLETED) {
      throw new BadRequestException('Solo se pueden reembolsar pagos completados');
    }

    try {
      await this.stripe.refunds.create({
        payment_intent: payment.paymentIntentId,
      });

      payment.status = PaymentStatus.REFUNDED;
      await this.paymentRepository.save(payment);

      return payment;
    } catch (error) {
      throw new BadRequestException(`Error al procesar reembolso: ${error.message}`);
    }
  }
}
