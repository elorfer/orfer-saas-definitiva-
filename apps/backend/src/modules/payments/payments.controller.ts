import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';

import { PaymentsService } from './payments.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User, UserRole } from '../../common/entities/user.entity';

@ApiTags('payments')
@Controller('payments')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('create-intent')
  @ApiOperation({ summary: 'Crear payment intent para suscripción' })
  @ApiResponse({ status: 201, description: 'Payment intent creado exitosamente' })
  async createPaymentIntent(
    @Body() body: { amount: number; currency?: string },
    @CurrentUser() user: User,
  ) {
    return this.paymentsService.createPaymentIntent(user.id, body.amount, body.currency);
  }

  @Post(':id/confirm')
  @ApiOperation({ summary: 'Confirmar pago' })
  @ApiResponse({ status: 200, description: 'Pago confirmado exitosamente' })
  @ApiResponse({ status: 404, description: 'Pago no encontrado' })
  async confirmPayment(@Param('id') paymentId: string) {
    return this.paymentsService.confirmPayment(paymentId);
  }

  @Get('my-payments')
  @ApiOperation({ summary: 'Obtener mis pagos' })
  @ApiResponse({ status: 200, description: 'Lista de pagos del usuario' })
  async getMyPayments(@CurrentUser() user: User) {
    return this.paymentsService.getUserPayments(user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener pago por ID' })
  @ApiResponse({ status: 200, description: 'Pago encontrado' })
  @ApiResponse({ status: 404, description: 'Pago no encontrado' })
  async getPaymentById(@Param('id') paymentId: string) {
    return this.paymentsService.getPaymentById(paymentId);
  }

  @Post(':id/refund')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Reembolsar pago (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Reembolso procesado exitosamente' })
  @ApiResponse({ status: 404, description: 'Pago no encontrado' })
  async refundPayment(@Param('id') paymentId: string) {
    return this.paymentsService.refundPayment(paymentId);
  }
}









