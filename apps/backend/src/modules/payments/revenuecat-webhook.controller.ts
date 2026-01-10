import {
    Controller,
    Post,
    Body,
    Headers,
    HttpCode,
    HttpStatus,
    Logger,
    BadRequestException,
    UnauthorizedException,
} from '@nestjs/common';
import { RevenueCatService } from './revenuecat.service';
import * as crypto from 'crypto';

/**
 * 🎯 RevenueCat Webhook Controller
 * 
 * Recibe y procesa webhooks de RevenueCat para sincronizar
 * el estado de suscripciones premium en tiempo real.
 * 
 * **URL del Webhook:** https://tu-dominio.com/api/webhooks/revenuecat
 * 
 * ⚠️ IMPORTANTE: Configurar esta URL en el dashboard de RevenueCat:
 * RevenueCat Dashboard → Project Settings → Webhooks → Add Webhook
 */
@Controller('webhooks/revenuecat')
export class RevenueCatWebhookController {
    private readonly logger = new Logger(RevenueCatWebhookController.name);

    // 🔐 SECRETO para verificar webhooks (obtenerlo de RevenueCat Dashboard)
    // CRÍTICO: Configurar en variables de entorno
    private readonly REVENUECAT_WEBHOOK_SECRET = process.env.REVENUECAT_WEBHOOK_SECRET || '';

    constructor(private readonly revenueCatService: RevenueCatService) {
        if (!this.REVENUECAT_WEBHOOK_SECRET) {
            this.logger.error(
                '❌ REVENUECAT_WEBHOOK_SECRET no configurado en variables de entorno. ' +
                '¡Los webhooks NO estarán protegidos!'
            );
        }
    }

    /**
     * Endpoint principal para recibir webhooks de RevenueCat
     * 
     * POST /api/webhooks/revenuecat
     * 
     * Headers requeridos:
     * - X-RevenueCat-Signature: Firma HMAC SHA-256 del payload
     * 
     * Body: JSON con el evento de RevenueCat
     */
    @Post()
    @HttpCode(HttpStatus.OK)
    async handleWebhook(
        @Body() payload: any,
        @Headers('x-revenuecat-signature') signature: string,
    ): Promise<{ received: boolean; message?: string }> {
        try {
            this.logger.log('📥 Webhook recibido de RevenueCat');

            // 1. Validar firma del webhook (seguridad crítica)
            if (this.REVENUECAT_WEBHOOK_SECRET) {
                this.validateWebhookSignature(payload, signature);
            } else {
                this.logger.warn('⚠️ Webhook sin validación de firma (NO RECOMENDADO en producción)');
            }

            // 2. Log del evento para debugging
            this.logWebhookEvent(payload);

            // 3. Procesar el evento
            const result = await this.revenueCatService.processWebhookEvent(payload);

            if (result.success) {
                this.logger.log(`✅ Webhook procesado exitosamente: ${result.message}`);
                return { received: true, message: result.message };
            } else {
                this.logger.error(`❌ Error procesando webhook: ${result.message}`);
                throw new BadRequestException(result.message);
            }

        } catch (error) {
            this.logger.error('❌ Error en webhook de RevenueCat', error.stack);

            // NO lanzar excepción para que RevenueCat no reintente indefinidamente
            // Retornar 200 pero loggear el error
            return {
                received: true,
                message: 'Error procesado, no se reintentará'
            };
        }
    }

    /**
     * Valida la firma HMAC SHA-256 del webhook
     * 
     * RevenueCat firma cada webhook con HMAC-SHA256 usando tu webhook secret.
     * Esto garantiza que el webhook proviene realmente de RevenueCat.
     */
    private validateWebhookSignature(payload: any, signature: string): void {
        if (!signature) {
            this.logger.error('❌ Webhook sin firma - posible intento de falsificación');
            throw new UnauthorizedException('Missing webhook signature');
        }

        // Convertir payload a string y ordenar keys
        const payloadString = JSON.stringify(payload);

        // Calcular HMAC SHA-256
        const expectedSignature = crypto
            .createHmac('sha256', this.REVENUECAT_WEBHOOK_SECRET)
            .update(payloadString)
            .digest('hex');

        // Comparación segura contra timing attacks
        const isValid = crypto.timingSafeEqual(
            Buffer.from(signature),
            Buffer.from(expectedSignature)
        );

        if (!isValid) {
            this.logger.error('❌ Firma de webhook inválida - posible intento de falsificación');
            this.logger.debug(`Firma recibida: ${signature}`);
            this.logger.debug(`Firma esperada: ${expectedSignature}`);
            throw new UnauthorizedException('Invalid webhook signature');
        }

        this.logger.debug('✅ Firma de webhook validada correctamente');
    }

    /**
     * Registra información detallada del webhook para debugging
     */
    private logWebhookEvent(payload: any): void {
        if (!payload || !payload.event) {
            this.logger.warn('⚠️ Payload de webhook inválido');
            return;
        }

        const { event } = payload;

        this.logger.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        this.logger.log('📊 EVENTO DE REVENUECAT');
        this.logger.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        this.logger.log(`🎯 Tipo: ${event.type}`);
        this.logger.log(`👤 Usuario: ${event.app_user_id}`);
        this.logger.log(`📦 Producto: ${event.product_id}`);
        this.logger.log(`💰 Precio: ${event.price} ${event.currency}`);

        if (event.expiration_at_ms) {
            const expiresAt = new Date(parseInt(event.expiration_at_ms));
            this.logger.log(`📅 Expira: ${expiresAt.toISOString()}`);
        }

        if (event.cancellation_at_ms) {
            const canceledAt = new Date(parseInt(event.cancellation_at_ms));
            this.logger.log(`❌ Cancelado: ${canceledAt.toISOString()}`);
        }

        this.logger.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    /**
     * Endpoint de salud para verificar que el webhook está funcionando
     * 
     * GET /api/webhooks/revenuecat/health
     */
    @Post('health')
    @HttpCode(HttpStatus.OK)
    healthCheck(): { status: string; timestamp: string } {
        return {
            status: 'ok',
            timestamp: new Date().toISOString(),
        };
    }
}
