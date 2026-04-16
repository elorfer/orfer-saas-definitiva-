import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, LessThanOrEqual, MoreThanOrEqual } from 'typeorm';

import { AudioAd, AdStatus, AdTargeting } from '../../common/entities/audio-ad.entity';
import { AdPlayLog } from '../../common/entities/ad-play-log.entity';
import { CreateAdDto } from './dto/create-ad.dto';
import { UpdateAdDto } from './dto/update-ad.dto';

@Injectable()
export class AdsService {
  private readonly logger = new Logger(AdsService.name);

  constructor(
    @InjectRepository(AudioAd)
    private readonly audioAdRepository: Repository<AudioAd>,
    @InjectRepository(AdPlayLog)
    private readonly adPlayLogRepository: Repository<AdPlayLog>,
  ) { }

  /**
   * Crear un nuevo anuncio
   */
  async create(createAdDto: CreateAdDto): Promise<AudioAd> {
    const ad = this.audioAdRepository.create({
      ...createAdDto,
      status: createAdDto.status || AdStatus.DRAFT,
      targeting: createAdDto.targeting || AdTargeting.ALL,
      frequencyPerHour: createAdDto.frequencyPerHour || 1,
      priority: createAdDto.priority || 0,
      isSkippable: createAdDto.isSkippable ?? true,
      skipAfterSeconds: createAdDto.skipAfterSeconds || 5,
    });

    return await this.audioAdRepository.save(ad);
  }

  /**
   * Obtener todos los anuncios (con filtros opcionales)
   */
  async findAll(
    page: number = 1,
    limit: number = 10,
    status?: AdStatus,
  ): Promise<{ ads: AudioAd[]; total: number }> {
    const queryBuilder = this.audioAdRepository.createQueryBuilder('ad');

    if (status) {
      queryBuilder.where('ad.status = :status', { status });
    }

    const [ads, total] = await queryBuilder
      .orderBy('ad.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();

    return { ads, total };
  }

  /**
   * Obtener un anuncio por ID
   */
  async findOne(id: string): Promise<AudioAd> {
    const ad = await this.audioAdRepository.findOne({
      where: { id },
      relations: ['playLogs'],
    });

    if (!ad) {
      throw new NotFoundException(`Anuncio con ID ${id} no encontrado`);
    }

    return ad;
  }

  /**
   * Actualizar un anuncio
   */
  async update(id: string, updateAdDto: UpdateAdDto): Promise<AudioAd> {
    const ad = await this.findOne(id);

    Object.assign(ad, updateAdDto);

    return await this.audioAdRepository.save(ad);
  }

  /**
   * Eliminar un anuncio
   */
  async remove(id: string): Promise<void> {
    const ad = await this.findOne(id);
    await this.audioAdRepository.remove(ad);
  }

  /**
   * Activar un anuncio
   */
  async activate(id: string): Promise<AudioAd> {
    const ad = await this.findOne(id);
    ad.status = AdStatus.ACTIVE;
    return await this.audioAdRepository.save(ad);
  }

  /**
   * Pausar un anuncio
   */
  async pause(id: string): Promise<AudioAd> {
    const ad = await this.findOne(id);
    ad.status = AdStatus.PAUSED;
    return await this.audioAdRepository.save(ad);
  }

  /**
   * Obtener anuncios activos
   */
  async findActive(): Promise<AudioAd[]> {
    const now = new Date();

    return await this.audioAdRepository.find({
      where: {
        status: AdStatus.ACTIVE,
      },
      order: {
        priority: 'DESC',
        createdAt: 'DESC',
      },
    });
  }

  /**
   * Algoritmo inteligente de selección de anuncios
   * Selecciona el mejor anuncio basado en:
   * - Targeting (género, artista, playlist)
   * - Frecuencia (no más de X veces por hora)
   * - Prioridad
   * - Fechas de campaña
   */
  /**
   * Algoritmo inteligente de selección de anuncios
   * Selecciona el mejor anuncio basado en:
   * 1. 🎯 Segmentación (Género, Artista, Playlist) - Prioridad nivel 1
   * 2. 📅 Límites de Campaña (Fechas válidas)
   * 3. 📉 Límite Diario (maxPlaysPerDay)
   * 4. 🕒 Frecuencia por Usuario (frequencyPerHour)
   * 5. 💎 Prioridad (0-100)
   * 6. 🎲 Aleatoriedad controlada (Shuffle para variedad)
   */
  async getNextAd(
    userId?: string,
    context?: {
      genre?: string;
      artist?: string;
      playlistId?: string;
    },
  ): Promise<AudioAd | null> {
    const now = new Date();
    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);

    this.logger.log(`[getNextAd] 🎯 Buscando anuncio inteligente. User: ${userId || 'Anon'}, Context: ${JSON.stringify(context)}`);

    // 1. Obtener todos los anuncios activos (candidatos base)
    const activeAds = await this.audioAdRepository
      .createQueryBuilder('ad')
      .where('ad.status = :status', { status: AdStatus.ACTIVE })
      .andWhere('(ad.startDate IS NULL OR ad.startDate <= :now)', { now })
      .andWhere('(ad.endDate IS NULL OR ad.endDate >= :now)', { now })
      .andWhere('ad.audioUrl IS NOT NULL')
      .andWhere("ad.audioUrl != ''")
      .getMany();

    if (activeAds.length === 0) {
      this.logger.warn('[getNextAd] ❌ No hay anuncios activos en el sistema.');
      return null;
    }

    // 2. Filtrar por Límite Diario (maxPlaysPerDay)
    // Obtenemos conteo de reproducciones de HOY para todos los anuncios
    const dailyPlayCounts = await this.adPlayLogRepository
      .createQueryBuilder('log')
      .select('log.ad_id', 'adId')
      .addSelect('COUNT(log.id)', 'count')
      .where('log.playedAt >= :startOfDay', { startOfDay })
      .groupBy('log.ad_id')
      .getRawMany();

    const playMapToday = new Map<string, number>();
    dailyPlayCounts.forEach(row => playMapToday.set(row.adId, parseInt(row.count)));

    let candidates = activeAds.filter(ad => {
      if (!ad.maxPlaysPerDay) return true;
      const playedToday = playMapToday.get(ad.id) || 0;
      return playedToday < ad.maxPlaysPerDay;
    });

    if (candidates.length === 0) {
      this.logger.warn('[getNextAd] 🛑 Todos los anuncios alcanzaron su límite diario.');
      return null;
    }

    // 3. Filtrar por Frecuencia horaria (Per-User)
    if (userId) {
      const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
      const userPlaysLastHour = await this.adPlayLogRepository.find({
        where: { userId, playedAt: MoreThanOrEqual(oneHourAgo) },
        relations: ['ad']
      });

      const userPlayMap = new Map<string, number>();
      userPlaysLastHour.forEach(log => {
        if (log.ad?.id) {
          userPlayMap.set(log.ad.id, (userPlayMap.get(log.ad.id) || 0) + 1);
        }
      });

      const beforeFrequencyCount = candidates.length;
      candidates = candidates.filter(ad => {
        const userPlays = userPlayMap.get(ad.id) || 0;
        return userPlays < ad.frequencyPerHour;
      });

      // 🔥 Fallback suave: Si el filtro de frecuencia deja al usuario sin NINGÚN anuncio 
      // pero hay anuncios disponibles en el sistema, permitimos repetir el menos visto recientemente
      if (candidates.length === 0 && beforeFrequencyCount > 0) {
        this.logger.warn('[getNextAd] 🕒 Usuario saturado. Forzando rotación mínima.');
        candidates = activeAds.filter(ad => {
          const playedToday = playMapToday.get(ad.id) || 0;
          return !ad.maxPlaysPerDay || playedToday < ad.maxPlaysPerDay;
        });
      }
    }

    // 4. Filtrar por Segmentación (Targeting) - NIVEL ELITE
    // Intentamos encontrar anuncios que coincidan perfectamente con el contexto (Rock, Jazz, etc.)
    const targetedAds = candidates.filter(ad => ad.matchesTargeting(context));

    let finalSelection: AudioAd[];
    if (targetedAds.length > 0) {
      this.logger.log(`[getNextAd] ✅ Encontrados ${targetedAds.length} anuncios segmentados para el contexto.`);
      finalSelection = targetedAds;
    } else {
      // Fallback: Si no hay anuncios para "Rock", usamos los anuncios marcados como "ALL" (Globales)
      this.logger.debug('[getNextAd] ℹ️ Sin segmentación específica. Usando anuncios globales.');
      finalSelection = candidates.filter(ad => ad.targeting === AdTargeting.ALL);
    }

    if (finalSelection.length === 0) {
      this.logger.warn('[getNextAd] ⚠️ Sin anuncios globales disponibles. Usando candidatos generales.');
      finalSelection = candidates;
    }

    // 5. Ranking por Prioridad (0-100)
    finalSelection.sort((a, b) => b.priority - a.priority);

    // Tomamos el grupo de mayor prioridad disponible
    const topPriority = finalSelection[0].priority;
    let bestCandidates = finalSelection.filter(ad => ad.priority === topPriority);

    // 6. ROTACIÓN CIRCULAR (Round-Robin / Least Played) - NIVEL ELITE
    // Para que la secuencia sea A -> B -> C -> D, elegimos el que el usuario haya oído MENOS veces.
    if (userId && bestCandidates.length > 1) {
      const candidateIds = bestCandidates.map(ad => ad.id);
      
      // Consultar historial de reproducciones de ESTE usuario para ESTOS candidatos
      const userPlays = await this.adPlayLogRepository
        .createQueryBuilder('log')
        .select('log.ad_id', 'adId')
        .addSelect('COUNT(log.id)', 'count')
        .where('log.user_id = :userId', { userId })
        .andWhere('log.ad_id IN (:...candidateIds)', { candidateIds })
        .groupBy('log.ad_id')
        .getRawMany();

      const userPlayMap = new Map<string, number>();
      userPlays.forEach(row => userPlayMap.set(row.adId, parseInt(row.count)));

      // Ordenar por quién ha sido escuchado menos veces por este usuario
      bestCandidates.sort((a, b) => {
        const countA = userPlayMap.get(a.id) || 0;
        const countB = userPlayMap.get(b.id) || 0;
        return countA - countB; // Ascendente (el menos escuchado primero)
      });

      // Si hay empates en el conteo mínimo, randomizar entre los empatados para variar un poco
      const minCount = userPlayMap.get(bestCandidates[0].id) || 0;
      const tiedForMin = bestCandidates.filter(ad => (userPlayMap.get(ad.id) || 0) === minCount);
      
      const randomIndex = Math.floor(Math.random() * tiedForMin.length);
      const selectedAd = tiedForMin[randomIndex];
      
      this.logger.log(`[getNextAd] 🔄 ROTACIÓN: "${selectedAd.title}" seleccionado por ser el menos escuchado por el usuario [Count: ${minCount}]`);
      return selectedAd;
    }

    // Fallback para usuarios anónimos o si solo hay un candidato: Random simple
    const randomIndex = Math.floor(Math.random() * bestCandidates.length);
    const selectedAd = bestCandidates[randomIndex];

    this.logger.log(`[getNextAd] 🎲 ✅ SELECCIONADO: "${selectedAd.title}" [Prio: ${selectedAd.priority}] [Target: ${selectedAd.targeting}]`);

    return selectedAd;
  }

  /**
   * Registrar una reproducción de anuncio
   */
  async logPlay(
    adId: string,
    userId: string | undefined,
    durationPlayed: number,
    wasCompleted: boolean,
    wasSkipped: boolean,
    context?: {
      genre?: string;
      artist?: string;
      playlistId?: string;
    },
  ): Promise<AdPlayLog | null> {
    this.logger.log(`[logPlay] ⚙️ Processing in Service: AdId=${adId}, Duration=${durationPlayed}, User=${userId}`);

    if (!adId) {
      this.logger.warn(`[logPlay] 🛑 Intento de registrar reproducción con adId nulo o inválido. Usuario: ${userId}. Ignorando.`);
      return null;
    }

    // Validar que durationPlayed sea un número válido
    if (durationPlayed === null || durationPlayed === undefined || isNaN(durationPlayed)) {
      this.logger.warn(`[logPlay] ⚠️ DurationPlayed inválido (${durationPlayed}) para anuncio ${adId}. Ajustando a 0.`);
      durationPlayed = 0;
    }

    try {
      const ad = await this.findOne(adId);
      // ... continúa la lógica normal

      // Crear log de reproducción
      const playLog = this.adPlayLogRepository.create({
        ad: ad, // ✅ Usar relación explícita para TypeORM
        userId,
        durationPlayed,
        wasCompleted,
        wasSkipped,
        wasClicked: false,
        contextGenre: context?.genre,
        contextArtist: context?.artist,
        contextPlaylistId: context?.playlistId,
      });

      const savedLog = await this.adPlayLogRepository.save(playLog);

      // Incrementar contador de reproducciones del anuncio
      ad.totalPlays += 1;
      await this.audioAdRepository.save(ad);

      this.logger.log(`[logPlay] 👾 ESTADO: REPRODUCCIÓN GUARDADA CORRECTAMENTE 👾 | Ad: ${ad.title} | User: ${userId || 'Anon'}`);
      return savedLog;
    } catch (error) {
      this.logger.warn(`[logPlay] ⚠️ Error al registrar reproducción para anuncio ${adId}: ${error.message}`);
      return null;
    }
  }

  /**
   * Registrar un click en un anuncio
   */
  async logClick(
    adId: string,
    userId: string | undefined,
  ): Promise<AdPlayLog> {
    const ad = await this.findOne(adId);

    // Buscar el último log de reproducción del usuario para este anuncio
    // (asumimos que el click ocurre durante o después de una reproducción)
    const lastPlayLog = await this.adPlayLogRepository.findOne({
      where: {
        ad: { id: adId }, // ✅ Query usar relación
        userId: userId || undefined,
      },
      order: {
        playedAt: 'DESC',
      },
    });

    if (lastPlayLog) {
      // Actualizar el log existente
      lastPlayLog.wasClicked = true;
      await this.adPlayLogRepository.save(lastPlayLog);
    } else {
      // Crear un nuevo log solo para el click (caso raro)
      const clickLog = this.adPlayLogRepository.create({
        ad: ad, // ✅ Crear usando relación
        userId,
        durationPlayed: 0,
        wasCompleted: false,
        wasSkipped: false,
        wasClicked: true,
      });
      await this.adPlayLogRepository.save(clickLog);
    }

    // Incrementar contador de clicks del anuncio
    ad.totalClicks += 1;
    await this.audioAdRepository.save(ad);

    return lastPlayLog || (await this.adPlayLogRepository.findOne({
      where: { ad: { id: adId }, userId: userId || undefined },
      order: { playedAt: 'DESC' },
    }))!;
  }

  /**
   * Obtener estadísticas de un anuncio
   */
  async getStats(adId: string): Promise<{
    totalPlays: number;
    totalClicks: number;
    completionRate: number;
    skipRate: number;
    clickThroughRate: number;
    averageDuration: number;
    recentPlays: AdPlayLog[];
  }> {
    const ad = await this.findOne(adId);

    const allLogs = await this.adPlayLogRepository.find({
      where: { ad: { id: adId } },
      order: { playedAt: 'DESC' },
      take: 100, // Últimas 100 reproducciones para estadísticas
    });

    const completed = allLogs.filter((log) => log.wasCompleted).length;
    const skipped = allLogs.filter((log) => log.wasSkipped).length;
    const clicked = allLogs.filter((log) => log.wasClicked).length;

    const totalDuration = allLogs.reduce((sum, log) => sum + log.durationPlayed, 0);
    const averageDuration = allLogs.length > 0 ? totalDuration / allLogs.length : 0;

    return {
      totalPlays: ad.totalPlays,
      totalClicks: ad.totalClicks,
      completionRate: allLogs.length > 0 ? (completed / allLogs.length) * 100 : 0,
      skipRate: allLogs.length > 0 ? (skipped / allLogs.length) * 100 : 0,
      clickThroughRate: allLogs.length > 0 ? (clicked / allLogs.length) * 100 : 0,
      averageDuration: Math.round(averageDuration),
      recentPlays: allLogs.slice(0, 50),
    };
  }

}

