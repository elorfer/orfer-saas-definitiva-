import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';
import { PlayHistory } from '../../common/entities/play-history.entity';
import { ConfigService } from '@nestjs/config';

interface ActiveUser {
  userId: string;
  socketIds: Set<string>;
  lastActivity: Date;
}

@Injectable()
export class RealtimeService {
  private readonly logger = new Logger(RealtimeService.name);
  
  // Almacenar usuarios activos en memoria (para conexiones WebSocket de admin)
  private activeUsers = new Map<string, ActiveUser>();

  // Para tracking de usuarios activos reales (basado en play_history)
  private readonly ACTIVE_THRESHOLD_MINUTES = 5; // Usuario activo si reprodujo algo en los últimos 5 minutos

  constructor(
    @InjectRepository(PlayHistory)
    private readonly playHistoryRepository: Repository<PlayHistory>,
    private readonly configService: ConfigService,
  ) {
    // Limpiar usuarios inactivos cada minuto
    setInterval(() => this.cleanupInactiveUsers(), 60000);
  }

  /**
   * Agregar un usuario activo (admin conectado vía WebSocket)
   */
  async addActiveUser(userId: string, socketId: string): Promise<void> {
    if (!this.activeUsers.has(userId)) {
      this.activeUsers.set(userId, {
        userId,
        socketIds: new Set([socketId]),
        lastActivity: new Date(),
      });
    } else {
      const user = this.activeUsers.get(userId);
      if (user) {
        user.socketIds.add(socketId);
        user.lastActivity = new Date();
      }
    }
  }

  /**
   * Remover un usuario activo
   */
  async removeActiveUser(userId: string, socketId: string): Promise<void> {
    const user = this.activeUsers.get(userId);
    if (user) {
      user.socketIds.delete(socketId);
      if (user.socketIds.size === 0) {
        this.activeUsers.delete(userId);
      } else {
        user.lastActivity = new Date();
      }
    }
  }

  /**
   * Obtener conteo de usuarios activos (admin conectados vía WebSocket)
   */
  async getActiveUsersCount(): Promise<number> {
    return this.activeUsers.size;
  }

  /**
   * Obtener conteo de usuarios realmente activos (reprodujeron música recientemente)
   */
  async getRealActiveUsersCount(): Promise<number> {
    try {
      const threshold = new Date();
      threshold.setMinutes(threshold.getMinutes() - this.ACTIVE_THRESHOLD_MINUTES);

      const result = await this.playHistoryRepository
        .createQueryBuilder('ph')
        .select('COUNT(DISTINCT ph.user_id)', 'count')
        .where('ph.played_at >= :threshold', { threshold })
        .getRawOne();

      return parseInt(result?.count || '0', 10);
    } catch (error) {
      this.logger.error(`Error obteniendo usuarios activos reales: ${error.message}`);
      return 0;
    }
  }

  /**
   * Obtener usuarios realmente activos con detalles
   */
  async getRealActiveUsers(limit: number = 10): Promise<any[]> {
    try {
      const threshold = new Date();
      threshold.setMinutes(threshold.getMinutes() - this.ACTIVE_THRESHOLD_MINUTES);

      const result = await this.playHistoryRepository
        .createQueryBuilder('ph')
        .select('ph.user_id', 'userId')
        .addSelect('MAX(ph.played_at)', 'lastPlay')
        .addSelect('COUNT(*)', 'playCount')
        .where('ph.played_at >= :threshold', { threshold })
        .groupBy('ph.user_id')
        .orderBy('MAX(ph.played_at)', 'DESC')
        .limit(limit)
        .getRawMany();

      return result.map((item: any) => ({
        userId: item.userId,
        lastPlay: new Date(item.lastPlay),
        playCount: parseInt(item.playCount, 10),
      }));
    } catch (error) {
      this.logger.error(`Error obteniendo usuarios activos: ${error.message}`);
      return [];
    }
  }

  /**
   * Limpiar usuarios inactivos de la memoria
   */
  private cleanupInactiveUsers(): void {
    const now = new Date();
    const INACTIVE_THRESHOLD = 5 * 60 * 1000; // 5 minutos

    for (const [userId, user] of this.activeUsers.entries()) {
      const timeSinceLastActivity = now.getTime() - user.lastActivity.getTime();
      if (timeSinceLastActivity > INACTIVE_THRESHOLD && user.socketIds.size === 0) {
        this.activeUsers.delete(userId);
      }
    }
  }

  /**
   * Obtener estadísticas combinadas
   */
  async getCombinedStats() {
    const [realActiveCount, adminConnections] = await Promise.all([
      this.getRealActiveUsersCount(),
      this.getActiveUsersCount(),
    ]);

    return {
      realActiveUsers: realActiveCount,
      adminConnections,
      timestamp: new Date().toISOString(),
    };
  }
}













