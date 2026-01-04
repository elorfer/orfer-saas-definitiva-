import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan, LessThan } from 'typeorm';
import { PlayHistory } from '../../common/entities/play-history.entity';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';

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

  // 🎯 CACHE: Evitar consultas repetidas a la BD
  private cachedActiveCount: number = 0;
  private cacheLastUpdated: Date = new Date(0);
  private readonly CACHE_TTL_MS = 30000; // Cache válido por 30 segundos

  constructor(
    @InjectRepository(PlayHistory)
    private readonly playHistoryRepository: Repository<PlayHistory>,
    private readonly configService: ConfigService,
  ) {
    // Limpiar usuarios inactivos cada minuto
    setInterval(() => this.cleanupInactiveUsers(), 60000);
  }

  /**
   * 🗑️ LIMPIEZA AUTOMÁTICA: Borrar registros de play_history mayores a 1 hora
   * Esto reduce costos de almacenamiento significativamente
   * Se ejecuta cada hora
   */
  @Cron(CronExpression.EVERY_HOUR)
  async cleanupOldPlayHistory() {
    try {
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() - 7); // 🎯 ULTRA ECONÓMICO: Solo 7 días de historial

      const result = await this.playHistoryRepository.delete({
        playedAt: LessThan(cutoff),
      });

      if (result.affected && result.affected > 0) {
        this.logger.log(`🗑️ [Cleanup] Eliminados ${result.affected} registros antiguos de play_history`);
      }
    } catch (error) {
      this.logger.error(`[Cleanup] Error limpiando play_history: ${error.message}`);
    }
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
   * 🎯 OPTIMIZADO: Usa cache para evitar consultas frecuentes a la BD
   */
  async getRealActiveUsersCount(): Promise<number> {
    try {
      // 🎯 CACHE CHECK: Si el cache es válido, retornar sin consultar BD
      const now = Date.now();
      if (now - this.cacheLastUpdated.getTime() < this.CACHE_TTL_MS) {
        return this.cachedActiveCount;
      }

      const threshold = new Date();
      threshold.setMinutes(threshold.getMinutes() - this.ACTIVE_THRESHOLD_MINUTES);

      const result = await this.playHistoryRepository
        .createQueryBuilder('ph')
        .select('COUNT(DISTINCT ph.userId)', 'count')
        .where('ph.playedAt >= :threshold', { threshold })
        .getRawOne();

      const count = parseInt(result?.count || '0', 10);

      // 🎯 ACTUALIZAR CACHE
      this.cachedActiveCount = count;
      this.cacheLastUpdated = new Date();

      this.logger.debug(`RealActiveUsersCount: ${count} (Threshold: ${threshold.toISOString()})`);
      return count;
    } catch (error) {
      this.logger.error(`Error obteniendo usuarios activos reales: ${error.message}`);
      return this.cachedActiveCount; // Retornar cache en caso de error
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
        .select('ph.userId', 'userId')
        .addSelect('MAX(ph.playedAt)', 'lastPlay')
        .addSelect('COUNT(*)', 'playCount')
        .where('ph.playedAt >= :threshold', { threshold })
        .groupBy('ph.userId')
        .orderBy('MAX(ph.playedAt)', 'DESC')
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



















