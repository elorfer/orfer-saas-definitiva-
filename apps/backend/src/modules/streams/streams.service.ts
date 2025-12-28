import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Inject,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import Redis from 'ioredis';
import { Song } from '../../common/entities/song.entity';
import { Artist } from '../../common/entities/artist.entity';
import { User } from '../../common/entities/user.entity';
import { Stream } from '../../common/entities/stream.entity';
import { UserListeningSession } from '../../common/entities/user-listening-session.entity';
import { TrackProgressDto } from './dto/track-progress.dto';
import { AffinityService } from '../affinity/affinity.service';

const MIN_STREAM_DURATION_MS = 30000; // 30 segundos
const RATE_LIMIT_WINDOW_MS = 30000; // 30 segundos entre streams del mismo usuario/canción

@Injectable()
export class StreamsService {
  private readonly logger = new Logger(StreamsService.name);

  constructor(
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
    @InjectRepository(Artist)
    private readonly artistRepository: Repository<Artist>,
    @InjectRepository(Stream)
    private readonly streamRepository: Repository<Stream>,
    @InjectRepository(UserListeningSession)
    private readonly sessionRepository: Repository<UserListeningSession>,
    @Inject('REDIS_CLIENT')
    private readonly redis: Redis,
    private readonly dataSource: DataSource,
    private readonly affinityService: AffinityService,
  ) { }

  /**
   * Track progress del usuario - valida si debe registrar stream
   */
  async trackProgress(userId: string, dto: TrackProgressDto): Promise<{
    shouldRegisterStream: boolean;
    streamRegistered: boolean;
    message?: string;
  }> {
    this.logger.debug(`[trackProgress] Usuario ${userId}, canción ${dto.songId}, progreso ${dto.progressMs}ms`);

    // Validar que la canción existe
    const song = await this.songRepository.findOne({
      where: { id: dto.songId },
      relations: ['artist'],
    });

    if (!song) {
      this.logger.warn(`[trackProgress] Canción no encontrada: ${dto.songId}`);
      throw new NotFoundException('Canción no encontrada');
    }

    // Validaciones anti-fraude
    if (!this.validatePlayback(dto)) {
      this.logger.debug(`[trackProgress] Validación anti-fraude falló para canción ${dto.songId}`);
      return {
        shouldRegisterStream: false,
        streamRegistered: false,
        message: 'Reproducción no válida',
      };
    }

    // Obtener o crear sesión de escucha
    let session = await this.sessionRepository.findOne({
      where: { userId, songId: dto.songId },
    });

    if (!session) {
      // Crear nueva sesión
      session = this.sessionRepository.create({
        userId,
        songId: dto.songId,
        maxProgressMs: dto.progressMs,
        startedAt: new Date(),
        lastProgressUpdate: new Date(),
      });
      await this.sessionRepository.save(session);
    } else {
      // Si la sesión ya fue validada y el progreso actual es muy bajo (nueva reproducción),
      // crear una nueva sesión
      const timeSinceLastUpdate = Date.now() - session.lastProgressUpdate.getTime();
      const isNewPlayback = dto.progressMs < 10000 && session.isStreamValidated; // Menos de 10s y ya validada
      const isLongPause = timeSinceLastUpdate > 60000 && session.isStreamValidated; // Más de 1 minuto pausado

      if (isNewPlayback) {
        this.logger.debug(
          `[trackProgress] Nueva reproducción detectada (Replay: progreso=${dto.progressMs}ms). Creando nueva sesión.`,
        );
        // Eliminar sesión anterior y crear una nueva
        await this.sessionRepository.remove(session);
        session = this.sessionRepository.create({
          userId,
          songId: dto.songId,
          maxProgressMs: dto.progressMs,
          startedAt: new Date(),
          lastProgressUpdate: new Date(),
        });
        await this.sessionRepository.save(session);
      } else if (isLongPause) {
        // ✅ FIX: Si es una pausa larga pero NO es un replay (progreso avanzado), 
        // es un RESUME. No borrar la sesión, solo actualizar timestamps.
        // Esto evita que 'startedAt' se resetee y cause "Progreso Sospechoso".
        this.logger.debug(
          `[trackProgress] Resumiendo sesión validada tras pausa larga (${dto.progressMs}ms). Manteniendo sesión.`,
        );
        session.lastProgressUpdate = new Date();
        if (dto.progressMs > session.maxProgressMs) {
          session.maxProgressMs = dto.progressMs;
        }
        await this.sessionRepository.save(session);
      } else {
        // Actualizar progreso máximo solo si es mayor
        if (dto.progressMs > session.maxProgressMs) {
          session.maxProgressMs = dto.progressMs;
          session.lastProgressUpdate = new Date();
          await this.sessionRepository.save(session);
        }
      }
    }

    // Validar si debe registrar stream (usar maxProgressMs de la sesión, no el progreso actual)

    // ✅ OPTIMIZACIÓN LOG: Evitar log excesivo en cada validación
    // this.logger.debug(`[StreamValidation] maxProgress=${session.maxProgressMs}ms`);

    const shouldRegister = this.shouldRegisterStream(
      session.maxProgressMs,
      dto.durationMs,
      session,
      dto.volume ?? 1.0,
      dto.isForeground ?? true,
    );

    if (!shouldRegister) {
      return {
        shouldRegisterStream: false,
        streamRegistered: false,
        message: `Progreso insuficiente o ya validado: ${session.maxProgressMs}ms`,
      };
    }

    // Intentar registrar stream (con rate limiting)
    const streamRegistered = await this.registerStreamIfValid(userId, dto.songId, session);

    this.logger.log(
      `[trackProgress] Resultado: shouldRegister=true, streamRegistered=${streamRegistered}, maxProgressMs=${session.maxProgressMs}ms`,
    );

    return {
      shouldRegisterStream: true,
      streamRegistered,
      message: streamRegistered ? 'Stream registrado' : 'Rate limit alcanzado',
    };
  }

  /**
   * Registrar stream (llamado internamente después de validar)
   */
  async registerStream(userId: string, songId: string): Promise<Stream> {
    // Verificar rate limit con Redis
    const rateLimitKey = `stream:rate_limit:${userId}:${songId}`;
    const exists = await this.redis.exists(rateLimitKey);

    if (exists) {
      throw new BadRequestException('Rate limit: solo 1 stream por 30 segundos');
    }

    // Validar canción y artista
    const song = await this.songRepository.findOne({
      where: { id: songId },
      relations: ['artist'],
    });

    if (!song) {
      throw new NotFoundException('Canción no encontrada');
    }

    // Usar transacción para atomicidad
    const stream = await this.dataSource.transaction(async (manager) => {
      // Crear stream
      const stream = manager.create(Stream, {
        userId,
        songId,
        durationListened: MIN_STREAM_DURATION_MS / 1000,
      });
      await manager.save(Stream, stream);

      // Incrementar contador de canción
      await manager.increment(Song, { id: songId }, 'totalStreams', 1);

      // Incrementar contador de artista
      if (song.artistId) {
        await manager.increment(Artist, { id: song.artistId }, 'totalStreams', 1);
      }

      // Marcar sesión como validada
      const session = await manager.findOne(UserListeningSession, {
        where: { userId, songId },
      });

      if (session) {
        session.isStreamValidated = true;
        session.streamValidatedAt = new Date();
        await manager.save(UserListeningSession, session);
      }

      return stream;
    });

    // Establecer rate limit en Redis (30 segundos)
    await this.redis.setex(rateLimitKey, RATE_LIMIT_WINDOW_MS / 1000, '1');

    this.logger.log(`Stream registrado: User ${userId} - Song ${songId}`);

    return stream;
  }

  /**
   * Validar si debe registrar stream
   * @param maxProgressMs - Progreso máximo alcanzado en la sesión (no el actual)
   */
  private shouldRegisterStream(
    maxProgressMs: number,
    durationMs: number,
    session: UserListeningSession,
    volume: number = 1.0,
    isForeground: boolean = true,
  ): boolean {
    // Si ya fue validado, no volver a registrar
    if (session.isStreamValidated) {
      // this.logger.debug(`[StreamValidation] Stream ya validado para esta sesión ${session.id}`);
      return false;
    }

    // ✅ REGLA 1: Debe haber escuchado al menos 30 segundos REALES (progreso máximo acumulado)
    if (maxProgressMs < MIN_STREAM_DURATION_MS) {
      this.logger.debug(
        `[StreamValidation] Progreso insuficiente: ${maxProgressMs}ms < ${MIN_STREAM_DURATION_MS}ms (sesión ${session.id})`,
      );
      return false;
    }

    // ✅ REGLA 3: Anti-fraude - Ignorar si volumen es 0 y app está en background
    if (!isForeground && volume === 0) {
      this.logger.warn(`[StreamValidation] Fraude detectado: Background + Volume 0 (sesión ${session.id})`);
      return false;
    }

    // ✅ REGLA 3: Validar que el progreso sea natural (no saltos sospechosos)
    // Comparar el progreso actual del request con el máximo permitido según el tiempo transcurrido
    const now = Date.now();
    const sessionStartTime = session.startedAt.getTime();
    const timeSinceStart = now - sessionStartTime;
    const maxAllowedProgress = timeSinceStart + 15000; // Tolerancia de 15 segundos para buffering/red

    this.logger.debug(
      `[StreamValidation] Verificando: maxProgressMs=${maxProgressMs}ms, timeSinceStart=${timeSinceStart}ms, maxAllowed=${maxAllowedProgress}ms (sesión ${session.id})`,
    );

    // Validar que el máximo progreso alcanzado no sea sospechoso
    // (no puede haber avanzado más de lo que el tiempo real permite)
    if (maxProgressMs > maxAllowedProgress) {
      this.logger.warn(
        `[StreamValidation] Progreso sospechoso: ${maxProgressMs}ms alcanzado en ${timeSinceStart}ms reales (sesión ${session.id})`,
      );
      return false;
    }

    // ✅ Validación pasada
    this.logger.log(`[StreamValidation] 🎧 Stream válido! ${maxProgressMs}ms (sesión ${session.id})`);

    // 🧠 OPERATION MEMORY: Trigger Afinidad
    // Llamada asíncrona para no bloquear
    this.affinityService.processStream(session.userId, session.songId);

    return true;
  }

  /**
   * Registrar un "Skip" (canción saltada antes de tiempo)
   * Impacto negativo en afinidad
   */
  async trackSkip(userId: string, songId: string, secondsPlayed: number): Promise<void> {
    this.logger.log(`[Skip] ⏭️ Usuario ${userId} saltó canción ${songId} a los ${secondsPlayed}s`);

    if (secondsPlayed < 5) {
      this.logger.log(`[Affinity] 📉 Penalizando afinidad (SKIP RÁPIDO) para usuario ${userId} con canción ${songId}`);
      await this.affinityService.processSkip(userId, songId, secondsPlayed);
    }
  }

  /**
   * Validaciones anti-fraude
   */
  private validatePlayback(dto: TrackProgressDto): boolean {
    // Ignorar si volumen es 0 (app en mute)
    if (dto.volume !== undefined && dto.volume === 0) {
      return false;
    }

    // Ignorar si app está en background (si se proporciona)
    if (dto.isForeground !== undefined && !dto.isForeground) {
      return false;
    }

    // Validar progreso no sea mayor a duración
    if (dto.progressMs > dto.durationMs) {
      return false;
    }

    return true;
  }

  /**
   * Registrar stream si es válido (con rate limiting)
   */
  private async registerStreamIfValid(
    userId: string,
    songId: string,
    session: UserListeningSession,
  ): Promise<boolean> {
    try {
      await this.registerStream(userId, songId);
      return true;
    } catch (error) {
      if (error instanceof BadRequestException) {
        // Rate limit
        return false;
      }
      this.logger.error(`Error registrando stream: ${error.message}`);
      return false;
    }
  }

  /**
   * Limpiar sesiones antiguas (ejecutar periódicamente)
   */
  async cleanupOldSessions(daysOld: number = 7): Promise<number> {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysOld);

    const result = await this.sessionRepository
      .createQueryBuilder()
      .delete()
      .where('created_at < :cutoffDate', { cutoffDate })
      .execute();

    return result.affected || 0;
  }

  /**
   * Obtener estadísticas de streams de una canción
   */
  async getSongStreamStats(songId: string, days: number = 30) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const [totalStreams, uniqueUsersResult] = await Promise.all([
      this.streamRepository
        .createQueryBuilder('stream')
        .where('stream.songId = :songId', { songId })
        .andWhere('stream.createdAt >= :startDate', { startDate })
        .getCount(),
      this.streamRepository
        .createQueryBuilder('stream')
        .select('COUNT(DISTINCT stream.userId)', 'count')
        .where('stream.songId = :songId', { songId })
        .andWhere('stream.createdAt >= :startDate', { startDate })
        .getRawOne(),
    ]);

    const uniqueUsers = parseInt(uniqueUsersResult?.count || '0', 10);

    return {
      totalStreams,
      uniqueUsers,
      period: days,
    };
  }
}

