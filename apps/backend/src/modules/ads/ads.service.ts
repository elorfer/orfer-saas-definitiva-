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
  ) {}

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

    this.logger.log(`[getNextAd] 📢 Iniciando selección de anuncio para usuario: ${userId || 'anónimo'}`);
    this.logger.log(`[getNextAd] 📢 Contexto: genre=${context?.genre}, artist=${context?.artist}, playlistId=${context?.playlistId}`);

    // 1. Obtener todos los anuncios activos que están dentro de sus fechas de campaña
    // IMPORTANTE: Solo incluir anuncios que tengan audioUrl (archivo subido)
    const activeAds = await this.audioAdRepository
      .createQueryBuilder('ad')
      .where('ad.status = :status', { status: AdStatus.ACTIVE })
      .andWhere('(ad.startDate IS NULL OR ad.startDate <= :now)', { now })
      .andWhere('(ad.endDate IS NULL OR ad.endDate >= :now)', { now })
      .andWhere('ad.audioUrl IS NOT NULL')
      .andWhere("ad.audioUrl != ''")
      .getMany();

    this.logger.log(`[getNextAd] 📢 Anuncios activos encontrados: ${activeAds.length}`);
    
    // ✅ DEBUG: Log detallado de cada anuncio activo
    if (activeAds.length > 0) {
      activeAds.forEach((ad, index) => {
        this.logger.log(`[getNextAd] 📢 Anuncio ${index + 1}: ${ad.title} (ID: ${ad.id}, Status: ${ad.status}, Targeting: ${ad.targeting}, AudioUrl: ${ad.audioUrl ? 'SÍ' : 'NO'})`);
      });
    }

    if (activeAds.length === 0) {
      this.logger.warn('[getNextAd] ❌ No hay anuncios activos disponibles (sin audioUrl o fuera de fechas)');
      return null;
    }

    // 2. Filtrar por targeting
    // ✅ FIX: Separar anuncios específicos de anuncios ALL para mejor control
    const specificTargetingAds = activeAds.filter((ad) => {
      // Incluir solo si NO es ALL y coincide con el targeting
      return ad.targeting !== AdTargeting.ALL && ad.matchesTargeting(context);
    });
    
    const allTargetingAds = activeAds.filter((ad) => ad.targeting === AdTargeting.ALL);

    this.logger.log(`[getNextAd] 📢 Anuncios con targeting específico: ${specificTargetingAds.length}`);
    this.logger.log(`[getNextAd] 📢 Anuncios con targeting ALL: ${allTargetingAds.length}`);

    // ✅ FIX: Priorizar anuncios específicos, pero incluir ALL si no hay específicos
    let matchingAds: AudioAd[] = [];
    
    if (specificTargetingAds.length > 0) {
      matchingAds = specificTargetingAds;
      this.logger.log(`[getNextAd] 📢 Usando ${matchingAds.length} anuncios con targeting específico`);
    } else if (allTargetingAds.length > 0) {
      matchingAds = allTargetingAds;
      this.logger.log(`[getNextAd] 📢 No hay anuncios específicos, usando ${matchingAds.length} anuncios con targeting ALL`);
    } else {
      this.logger.warn(`[getNextAd] ❌ No hay anuncios disponibles (ni específicos ni ALL)`);
      return null;
    }

    // 3. Verificar frecuencia por hora (si hay userId)
    let eligibleAds = matchingAds;
    let adsExcludedByFrequency: AudioAd[] = [];
    
    if (userId) {
      const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

      // Obtener reproducciones del usuario en la última hora
      const recentPlays = await this.adPlayLogRepository.find({
        where: {
          userId,
          playedAt: MoreThanOrEqual(oneHourAgo),
        },
      });

      this.logger.log(`[getNextAd] 📢 Reproducciones del usuario en última hora: ${recentPlays.length}`);

      // Contar reproducciones por anuncio en la última hora
      const playCountsByAd: Record<string, number> = {};
      recentPlays.forEach((play) => {
        playCountsByAd[play.adId] = (playCountsByAd[play.adId] || 0) + 1;
      });

      // Filtrar anuncios que no han excedido su frecuencia por hora
      const beforeFreqFilter = eligibleAds.length;
      adsExcludedByFrequency = [];
      eligibleAds = matchingAds.filter((ad) => {
        const playCount = playCountsByAd[ad.id] || 0;
        const isEligible = playCount < ad.frequencyPerHour;
        if (!isEligible) {
          this.logger.log(`[getNextAd] 📢 Anuncio ${ad.id} excluido: frecuencia por hora excedida (${playCount}/${ad.frequencyPerHour})`);
          adsExcludedByFrequency.push(ad);
        }
        return isEligible;
      });
      
      this.logger.log(`[getNextAd] 📢 Después de filtrar frecuencia por hora: ${eligibleAds.length} de ${beforeFreqFilter}`);
      
      // ✅ FIX: Si no hay anuncios elegibles pero hay anuncios excluidos por frecuencia, usarlos como fallback
      if (eligibleAds.length === 0 && adsExcludedByFrequency.length > 0) {
        this.logger.log(`[getNextAd] 📢 No hay anuncios elegibles, usando ${adsExcludedByFrequency.length} anuncios excluidos por frecuencia como fallback (permitiendo repetición)`);
        eligibleAds = adsExcludedByFrequency;
      }
    }

    // 4. Verificar límite diario (si hay userId)
    let adsExcludedByDailyLimit: AudioAd[] = [];
    if (userId && eligibleAds.length > 0) {
      const todayStart = new Date(now);
      todayStart.setHours(0, 0, 0, 0);

      const todayPlays = await this.adPlayLogRepository.find({
        where: {
          userId,
          playedAt: MoreThanOrEqual(todayStart),
        },
      });

      this.logger.log(`[getNextAd] 📢 Reproducciones del usuario hoy: ${todayPlays.length}`);

      const playCountsByAdToday: Record<string, number> = {};
      todayPlays.forEach((play) => {
        playCountsByAdToday[play.adId] = (playCountsByAdToday[play.adId] || 0) + 1;
      });

      const beforeDailyFilter = eligibleAds.length;
      adsExcludedByDailyLimit = [];
      eligibleAds = eligibleAds.filter((ad) => {
        if (!ad.maxPlaysPerDay) return true; // Sin límite diario
        const playCount = playCountsByAdToday[ad.id] || 0;
        const isEligible = playCount < ad.maxPlaysPerDay;
        if (!isEligible) {
          this.logger.log(`[getNextAd] 📢 Anuncio ${ad.id} excluido: límite diario excedido (${playCount}/${ad.maxPlaysPerDay})`);
          adsExcludedByDailyLimit.push(ad);
        }
        return isEligible;
      });
      
      this.logger.log(`[getNextAd] 📢 Después de filtrar límite diario: ${eligibleAds.length} de ${beforeDailyFilter}`);
      
      // ✅ FIX: Si no hay anuncios elegibles pero hay anuncios excluidos por límite diario, usarlos como fallback
      if (eligibleAds.length === 0 && adsExcludedByDailyLimit.length > 0) {
        this.logger.log(`[getNextAd] 📢 No hay anuncios elegibles, usando ${adsExcludedByDailyLimit.length} anuncios excluidos por límite diario como fallback (permitiendo repetición)`);
        eligibleAds = adsExcludedByDailyLimit;
      }
    }

    if (eligibleAds.length === 0) {
      this.logger.warn('[getNextAd] ❌ No hay anuncios elegibles después de aplicar todos los filtros');
      return null;
    }

    // 5. Ordenar por prioridad (mayor prioridad primero)
    eligibleAds.sort((a, b) => b.priority - a.priority);

    // 6. Seleccionar aleatoriamente entre los top 3 (o todos si hay menos de 3)
    const topAds = eligibleAds.slice(0, 3);
    const randomIndex = Math.floor(Math.random() * topAds.length);
    const selectedAd = topAds[randomIndex];

    this.logger.log(`[getNextAd] ✅ Anuncio seleccionado: ${selectedAd.title} (ID: ${selectedAd.id}, prioridad: ${selectedAd.priority})`);
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
  ): Promise<AdPlayLog> {
    const ad = await this.findOne(adId);

    // Crear log de reproducción
    const playLog = this.adPlayLogRepository.create({
      adId,
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

    return savedLog;
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
        adId,
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
        adId,
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
      where: { adId, userId: userId || undefined },
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
      where: { adId },
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

