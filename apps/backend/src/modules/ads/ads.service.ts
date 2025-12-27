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
  async getNextAd(
    userId?: string,
    context?: {
      genre?: string;
      artist?: string;
      playlistId?: string;
    },
  ): Promise<AudioAd | null> {
    const now = new Date();

    this.logger.log(`[getNextAd] 🌍 GLOBAL SHUFFLE MODE. Usuario: ${userId || 'anónimo'}. Ignorando targeting.`);

    // 1. Obtener todos los anuncios activos (sin targeting)
    const activeAds = await this.audioAdRepository
      .createQueryBuilder('ad')
      .where('ad.status = :status', { status: AdStatus.ACTIVE })
      .andWhere('(ad.startDate IS NULL OR ad.startDate <= :now)', { now })
      .andWhere('(ad.endDate IS NULL OR ad.endDate >= :now)', { now })
      .andWhere('ad.audioUrl IS NOT NULL')
      .andWhere("ad.audioUrl != ''")
      .getMany();

    this.logger.debug(`[getNextAd] 🔍 Query Result - Active Ads Found: ${activeAds.length}`);
    activeAds.forEach(ad => this.logger.debug(`   - Candidate: ${ad.title} (${ad.id})`));

    if (activeAds.length === 0) {
      this.logger.warn('[getNextAd] ❌ No hay anuncios activos disponibles (Query returned 0).');
      return null;
    }

    this.logger.log(`[getNextAd] 📢 Pool de anuncios activos: ${activeAds.length}`);

    // 2. Verificar frecuencia por hora (Protección de usuario)
    let eligibleAds = activeAds;

    if (userId) {
      this.logger.debug(`[getNextAd] 👤 Checking frequency for user: ${userId}`);
      // ... Lógica de frecuencia simplificada ...
      const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
      const recentPlays = await this.adPlayLogRepository.find({
        where: { userId, playedAt: MoreThanOrEqual(oneHourAgo) },
      });

      this.logger.debug(`[getNextAd] 🕒 Recent plays (last 1h): ${recentPlays.length}`);

      const playCountsByAd: Record<string, number> = {};
      recentPlays.forEach(play => {
        const adId = play.ad?.id;
        if (adId) playCountsByAd[adId] = (playCountsByAd[adId] || 0) + 1;
      });

      eligibleAds = activeAds.filter(ad => {
        const plays = playCountsByAd[ad.id] || 0;
        const passed = plays < ad.frequencyPerHour;
        if (!passed) this.logger.debug(`   - Filtered out ${ad.title}: plays(${plays}) >= limit(${ad.frequencyPerHour})`);
        return passed;
      });

      this.logger.debug(`[getNextAd] 📉 Eligible after frequency check: ${eligibleAds.length}`);

      if (eligibleAds.length === 0) {
        this.logger.warn('[getNextAd] ⚠️ Todos los anuncios excedieron frecuencia horaria. Usando fallback con repetición.');
        eligibleAds = activeAds; // Fallback extremo: permitir repetir si no hay nada más
      }
    }

    // 3. SHUFFLE GLOBAL (La clave de la variedad)
    // Fisher-Yates Shuffle para máxima aleatoriedad
    for (let i = eligibleAds.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [eligibleAds[i], eligibleAds[j]] = [eligibleAds[j], eligibleAds[i]];
    }

    const selectedAd = eligibleAds[0];
    this.logger.log(`[getNextAd] 🎲 ✅ Anuncio seleccionado (Random): ${selectedAd.title} (ID: ${selectedAd.id})`);

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

