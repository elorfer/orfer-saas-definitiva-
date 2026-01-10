import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../../common/entities/user.entity';

/**
 * 🎯 RevenueCat Service - Gestión de Suscripciones Premium
 * 
 * Este servicio maneja la sincronización entre RevenueCat y la base de datos
 * de Struky para gestionar suscripciones premium.
 * 
 * **Responsabilidades:**
 * - Procesar webhooks de RevenueCat
 * - Actualizar estado premium de usuarios
 * - Sincronizar datos de suscripciones
 * - Manejar eventos de compra, renovación y cancelación
 */
@Injectable()
export class RevenueCatService {
    private readonly logger = new Logger(RevenueCatService.name);

    // Tipos de eventos de RevenueCat que procesamos
    private readonly SUPPORTED_EVENTS = [
        'INITIAL_PURCHASE',       // Primera compra
        'RENEWAL',                // Renovación automática
        'CANCELLATION',           // Usuario canceló
        'UNCANCELLATION',         // Usuario reactivó
        'NON_RENEWING_PURCHASE',  // Compra no renovable
        'EXPIRATION',             // Suscripción expiró
        'BILLING_ISSUE',          // Problema de pago
        'PRODUCT_CHANGE',         // Cambio de plan
    ];

    constructor(
        @InjectRepository(User)
        private readonly userRepository: Repository<User>,
    ) { }

    /**
     * Procesa un evento de webhook de RevenueCat
     * 
     * @param webhookData - Datos del webhook enviados por RevenueCat
     * @returns Resultado del procesamiento
     */
    async processWebhookEvent(webhookData: any): Promise<{ success: boolean; message: string }> {
        try {
            const { event } = webhookData;

            this.logger.log(`📥 Webhook recibido: ${event.type}`);

            // Validar que sea un evento que procesamos
            if (!this.SUPPORTED_EVENTS.includes(event.type)) {
                this.logger.warn(`⚠️ Evento no soportado: ${event.type}`);
                return { success: true, message: 'Event type not processed' };
            }

            // Extraer información del subscriber
            const appUserId = event.app_user_id; // Este es el ID que enviamos desde Flutter
            const productId = event.product_id;
            const expiresDate = event.expiration_at_ms
                ? new Date(parseInt(event.expiration_at_ms))
                : null;

            this.logger.debug(`👤 App User ID: ${appUserId}`);
            this.logger.debug(`📦 Product ID: ${productId}`);
            this.logger.debug(`📅 Expires at: ${expiresDate}`);

            // Buscar usuario por el app_user_id (debe coincidir con el ID de tu DB)
            const user = await this.userRepository.findOne({
                where: { id: appUserId }
            });

            if (!user) {
                this.logger.error(`❌ Usuario no encontrado: ${appUserId}`);
                return { success: false, message: 'User not found' };
            }

            // Procesar según el tipo de evento
            await this.handleEventType(event.type, user, webhookData.event);

            return { success: true, message: 'Event processed successfully' };

        } catch (error) {
            this.logger.error('❌ Error procesando webhook de RevenueCat', error.stack);
            throw error;
        }
    }

    /**
     * Maneja diferentes tipos de eventos de RevenueCat
     */
    private async handleEventType(
        eventType: string,
        user: User,
        eventData: any,
    ): Promise<void> {
        switch (eventType) {
            case 'INITIAL_PURCHASE':
            case 'RENEWAL':
            case 'UNCANCELLATION':
            case 'NON_RENEWING_PURCHASE':
                await this.activatePremium(user, eventData);
                break;

            case 'CANCELLATION':
                await this.handleCancellation(user, eventData);
                break;

            case 'EXPIRATION':
                await this.deactivatePremium(user);
                break;

            case 'BILLING_ISSUE':
                await this.handleBillingIssue(user, eventData);
                break;

            case 'PRODUCT_CHANGE':
                await this.handleProductChange(user, eventData);
                break;

            default:
                this.logger.warn(`⚠️ Tipo de evento no manejado: ${eventType}`);
        }
    }

    /**
     * Activa el estado premium del usuario
     */
    private async activatePremium(user: User, eventData: any): Promise<void> {
        this.logger.log(`✅ Activando premium para usuario: ${user.id}`);

        const expiresAt = eventData.expiration_at_ms
            ? new Date(parseInt(eventData.expiration_at_ms))
            : null;

        // Actualizar campos de RevenueCat
        user.isPremium = true;
        user.premiumExpiresAt = expiresAt;
        user.revenuecatUserId = eventData.app_user_id;
        user.revenuecatCustomerId = eventData.subscriber_attributes?.$revenueCatId || null;
        user.lastRevenuecatSync = new Date();

        await this.userRepository.save(user);

        this.logger.log(
            `✅ Premium activado para ${user.email} - Expira: ${expiresAt || 'Lifetime'}`
        );
    }

    /**
     * Maneja la cancelación de una suscripción
     * 
     * IMPORTANTE: En RevenueCat, una cancelación NO desactiva inmediatamente el premium.
     * El usuario mantiene acceso hasta la fecha de expiración.
     */
    private async handleCancellation(user: User, eventData: any): Promise<void> {
        this.logger.log(`⚠️ Cancelación detectada para usuario: ${user.id}`);

        const expiresAt = eventData.expiration_at_ms
            ? new Date(parseInt(eventData.expiration_at_ms))
            : null;

        // El usuario sigue siendo premium hasta que expire
        user.lastRevenuecatSync = new Date();

        // Si la fecha de expiración ya pasó, desactivar
        if (expiresAt && expiresAt <= new Date()) {
            user.isPremium = false;
            this.logger.log(`❌ Premium desactivado inmediatamente (fecha expirada)`);
        } else {
            this.logger.log(
                `ℹ️ Usuario mantiene premium hasta: ${expiresAt}`
            );
        }

        await this.userRepository.save(user);
    }

    /**
     * Desactiva el estado premium del usuario
     */
    private async deactivatePremium(user: User): Promise<void> {
        this.logger.log(`❌ Desactivando premium para usuario: ${user.id}`);

        user.isPremium = false;
        user.lastRevenuecatSync = new Date();

        await this.userRepository.save(user);

        this.logger.log(`❌ Premium desactivado para ${user.email}`);
    }

    /**
     * Maneja problemas de facturación
     */
    private async handleBillingIssue(user: User, eventData: any): Promise<void> {
        this.logger.warn(`⚠️ Problema de facturación para usuario: ${user.id}`);

        // Mantener premium temporalmente, pero registrar el problema
        user.lastRevenuecatSync = new Date();
        await this.userRepository.save(user);

        // Aquí podrías enviar un email al usuario notificándole del problema
        this.logger.warn(`⚠️ Usuario ${user.email} tiene un problema de pago`);
    }

    /**
     * Maneja cambios de producto/plan
     */
    private async handleProductChange(user: User, eventData: any): Promise<void> {
        this.logger.log(`🔄 Cambio de producto para usuario: ${user.id}`);

        const newExpiresAt = eventData.expiration_at_ms
            ? new Date(parseInt(eventData.expiration_at_ms))
            : null;

        user.premiumExpiresAt = newExpiresAt;
        user.isPremium = true; // Asegurar que sigue siendo premium
        user.lastRevenuecatSync = new Date();

        await this.userRepository.save(user);

        this.logger.log(
            `✅ Producto actualizado para ${user.email} - Nueva expiración: ${newExpiresAt}`
        );
    }

    /**
     * Verifica y sincroniza el estado premium de un usuario específico
     * (útil para verificaciones manuales o sincronización forzada)
     */
    async syncUserPremiumStatus(userId: string): Promise<User> {
        const user = await this.userRepository.findOne({ where: { id: userId } });

        if (!user) {
            throw new Error('Usuario no encontrado');
        }

        // Verificar si el premium ha expirado
        if (user.isPremium && user.premiumExpiresAt) {
            const now = new Date();
            if (user.premiumExpiresAt < now) {
                this.logger.log(`⏰ Premium expirado para usuario: ${userId}`);
                user.isPremium = false;
                user.lastRevenuecatSync = new Date();
                await this.userRepository.save(user);
            }
        }

        return user;
    }

    /**
     * Obtiene estadísticas de usuarios premium
     */
    async getPremiumStats(): Promise<{
        totalPremiumUsers: number;
        activeSubscriptions: number;
        expiringThisMonth: number;
    }> {
        const totalPremiumUsers = await this.userRepository.count({
            where: { isPremium: true },
        });

        const now = new Date();
        const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);

        const expiringThisMonth = await this.userRepository
            .createQueryBuilder('user')
            .where('user.isPremium = :isPremium', { isPremium: true })
            .andWhere('user.premiumExpiresAt <= :endOfMonth', { endOfMonth })
            .andWhere('user.premiumExpiresAt > :now', { now })
            .getCount();

        return {
            totalPremiumUsers,
            activeSubscriptions: totalPremiumUsers,
            expiringThisMonth,
        };
    }
}
