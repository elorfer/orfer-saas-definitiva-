import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { RevenueCatService } from './revenuecat.service';
import { RevenueCatWebhookController } from './revenuecat-webhook.controller';
import { Payment } from '../../common/entities/payment.entity';
import { User } from '../../common/entities/user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Payment, User])],
  controllers: [
    PaymentsController,
    RevenueCatWebhookController, // Webhook de RevenueCat
  ],
  providers: [
    PaymentsService,
    RevenueCatService, // Servicio de RevenueCat
  ],
  exports: [
    PaymentsService,
    RevenueCatService, // Exportar para uso en otros módulos
  ],
})
export class PaymentsModule { }









