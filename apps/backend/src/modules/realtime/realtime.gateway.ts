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

interface AuthenticatedSocket extends Socket {
  userId?: string;
  userRole?: string;
}

@WebSocketGateway({
  cors: {
    origin: process.env.ADMIN_FRONTEND_URL || 'http://localhost:3002',
    credentials: true,
  },
  namespace: '/realtime',
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly realtimeService: RealtimeService,
  ) {}

  async handleConnection(client: AuthenticatedSocket) {
    try {
      // Verificar autenticación JWT desde query params o headers
      const token = client.handshake.auth?.token || 
                   client.handshake.query?.token as string;

      if (!token) {
        this.logger.warn(`Cliente intentó conectar sin token: ${client.id}`);
        client.disconnect();
        return;
      }

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

      // Solo permitir conexiones de administradores para el monitoreo
      if (client.userRole !== 'admin') {
        this.logger.warn(`Usuario no admin intentó conectar: ${client.userId}`);
        client.disconnect();
        return;
      }

      // Registrar usuario activo
      await this.realtimeService.addActiveUser(client.userId, client.id);
      
      // Enviar conteo actual de usuarios activos
      const activeUsersCount = await this.realtimeService.getActiveUsersCount();
      this.server.emit('activeUsersCount', { count: activeUsersCount });

      this.logger.log(`Admin conectado: ${client.userId} (${client.id})`);
    } catch (error) {
      this.logger.error(`Error en conexión: ${error.message}`);
      client.disconnect();
    }
  }

  async handleDisconnect(client: AuthenticatedSocket) {
    if (client.userId) {
      await this.realtimeService.removeActiveUser(client.userId, client.id);
      
      // Enviar conteo actualizado
      const activeUsersCount = await this.realtimeService.getActiveUsersCount();
      this.server.emit('activeUsersCount', { count: activeUsersCount });

      this.logger.log(`Admin desconectado: ${client.userId} (${client.id})`);
    }
  }

  @SubscribeMessage('requestActiveUsers')
  async handleRequestActiveUsers(@ConnectedSocket() client: AuthenticatedSocket) {
    const activeUsersCount = await this.realtimeService.getActiveUsersCount();
    client.emit('activeUsersCount', { count: activeUsersCount });
  }

  // Método para emitir actualización de usuarios activos (llamado externamente)
  async broadcastActiveUsersCount() {
    const count = await this.realtimeService.getActiveUsersCount();
    this.server.emit('activeUsersCount', { count });
  }
}

