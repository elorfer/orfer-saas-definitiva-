import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger, UseGuards } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { RealtimeService } from './realtime.service';
import { Interval } from '@nestjs/schedule';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  userRole?: string;
}

@WebSocketGateway({
  cors: {
    origin: '*', // Permitir conexiones desde cualquier origen (app móvil)
    credentials: true,
  },
  namespace: '/realtime',
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(RealtimeGateway.name);
  // Almacenar sockets de usuarios por userId para notificaciones específicas
  private readonly userSockets = new Map<string, Set<string>>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly realtimeService: RealtimeService,
  ) { }

  async handleConnection(client: AuthenticatedSocket) {
    try {
      this.logger.log(`🔌 Intento de conexión desde: ${client.handshake.address} (${client.id})`);
      this.logger.debug(`Handshake auth: ${JSON.stringify(client.handshake.auth)}`);
      this.logger.debug(`Handshake query: ${JSON.stringify(client.handshake.query)}`);

      // Verificar autenticación JWT desde query params o headers
      const token = client.handshake.auth?.token ||
        client.handshake.query?.token as string;

      if (!token) {
        this.logger.warn(`⚠️ Cliente intentó conectar sin token: ${client.id}`);
        client.disconnect();
        return;
      }

      this.logger.debug(`✅ Token encontrado para cliente: ${client.id}`);

      // Verificar y decodificar el token
      let payload: any;
      try {
        payload = this.jwtService.verify(token);
      } catch (error) {
        this.logger.warn(`Token inválido o expirado para cliente: ${client.id} - ${error.message}`);
        client.disconnect();
        return;
      }

      if (!payload || !payload.sub) {
        this.logger.warn(`Token sin payload válido para cliente: ${client.id}`);
        client.disconnect();
        return;
      }

      // Guardar información del usuario en el socket
      client.userId = payload.sub;
      client.userRole = payload.role;

      // Unir al usuario a una sala personalizada para recibir notificaciones
      const userRoom = `user:${client.userId}`;
      client.join(userRoom);

      // Registrar socket del usuario para notificaciones específicas
      if (!this.userSockets.has(client.userId)) {
        this.userSockets.set(client.userId, new Set());
      }
      this.userSockets.get(client.userId)!.add(client.id);

      // Solo registrar como "activo" si es admin (para estadísticas de admin)
      if (client.userRole === 'admin') {
        // Unir admin a la sala 'admin' para recibir eventos de monitoreo
        client.join('admin');
        await this.realtimeService.addActiveUser(client.userId, client.id);

        // Enviar conteo actual de usuarios realmente activos (listeners) a admins
        const activeUsersCount = await this.realtimeService.getRealActiveUsersCount();
        this.server.to('admin').emit('activeUsersCount', { count: activeUsersCount });

        this.logger.log(`Admin conectado: ${client.userId} (${client.id})`);
      } else {
        this.logger.log(`Usuario conectado: ${client.userId} (${client.id})`);
      }
    } catch (error) {
      this.logger.error(`Error en conexión: ${error.message}`);
      client.disconnect();
    }
  }

  async handleDisconnect(client: AuthenticatedSocket) {
    if (client.userId) {
      // Remover socket del usuario
      const userSockets = this.userSockets.get(client.userId);
      if (userSockets) {
        userSockets.delete(client.id);
        if (userSockets.size === 0) {
          this.userSockets.delete(client.userId);
        }
      }

      // Solo actualizar estadísticas de admin si era admin
      if (client.userRole === 'admin') {
        await this.realtimeService.removeActiveUser(client.userId, client.id);

        // Enviar conteo actualizado de usuarios realmente activos a admins
        const activeUsersCount = await this.realtimeService.getRealActiveUsersCount();
        this.server.to('admin').emit('activeUsersCount', { count: activeUsersCount });

        this.logger.log(`Admin desconectado: ${client.userId} (${client.id})`);
      } else {
        this.logger.log(`Usuario desconectado: ${client.userId} (${client.id})`);
      }
    }
  }

  @SubscribeMessage('requestActiveUsers')
  async handleRequestActiveUsers(@ConnectedSocket() client: AuthenticatedSocket) {
    const activeUsersCount = await this.realtimeService.getRealActiveUsersCount();
    client.emit('activeUsersCount', { count: activeUsersCount });
  }

  // Método para emitir actualización de usuarios activos (llamado externamente o vía Interval)
  // 🎯 OPTIMIZADO: Cada 30 segundos en lugar de 15 para reducir carga
  @Interval(30000)
  async broadcastActiveUsersCount() {
    const count = await this.realtimeService.getRealActiveUsersCount();
    this.server.to('admin').emit('activeUsersCount', { count });
    this.logger.debug(`📢 Broadcast: ${count} usuarios reales activos`);
  }

  /**
   * Emitir evento de cambio de estado premium a un usuario específico
   * @param userId ID del usuario que recibirá la notificación
   * @param subscriptionStatus Nuevo estado de suscripción
   */
  notifyPremiumStatusChange(userId: string, subscriptionStatus: string): void {
    const userRoom = `user:${userId}`;
    const isConnected = this.isUserConnected(userId);

    this.logger.log(`📢 Emitiendo notificación premium a usuario ${userId}`);
    this.logger.log(`   - Sala: ${userRoom}`);
    this.logger.log(`   - Estado: ${subscriptionStatus}`);
    this.logger.log(`   - Usuario conectado: ${isConnected}`);
    this.logger.log(`   - Sockets del usuario: ${this.userSockets.get(userId)?.size ?? 0}`);

    const eventData = {
      userId,
      subscriptionStatus,
      timestamp: new Date().toISOString(),
    };

    this.server.to(userRoom).emit('premiumStatusChanged', eventData);
    this.logger.log(`✅ Notificación premium enviada a sala ${userRoom}: ${JSON.stringify(eventData)}`);
  }

  /**
   * Verificar si un usuario está conectado
   */
  isUserConnected(userId: string): boolean {
    return this.userSockets.has(userId) && this.userSockets.get(userId)!.size > 0;
  }

  /**
   * 🆙 Emitir evento de prueba de actualización a todos los usuarios conectados
   */
  broadcastUpdateTest(): void {
    this.logger.log('📢 Emitiendo evento de prueba de actualización a TODOS los usuarios');
    this.server.emit('showUpdateTest', {
      timestamp: new Date().toISOString(),
      isMandatory: true,
    });
  }
}

