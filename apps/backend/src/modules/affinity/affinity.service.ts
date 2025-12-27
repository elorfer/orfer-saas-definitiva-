import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserAffinity, AffinityEntityType } from '../../common/entities/user-affinity.entity';
import { Song } from '../../common/entities/song.entity';

@Injectable()
export class AffinityService {
    private readonly logger = new Logger(AffinityService.name);

    // PESOS DE AFINIDAD
    private readonly WEIGHTS = {
        PLAY: {
            ARTIST: 1.0,  // Play completo suma 1 punto al artista
            GENRE: 0.5,   // Play completo suma 0.5 al género
        },
        SKIP: {
            ARTIST: -0.5, // Skip rápido resta 0.5 al artista (penalización)
            GENRE: -0.2,  // Skip rápido resta 0.2 al género
        },
    };

    constructor(
        @InjectRepository(UserAffinity)
        private readonly affinityRepository: Repository<UserAffinity>,
        @InjectRepository(Song)
        private readonly songRepository: Repository<Song>,
    ) { }

    /**
     * Procesa un stream válido (play > 30s)
     */
    async processStream(userId: string, songId: string) {
        try {
            const song = await this.getSongWithRelations(songId);
            if (!song) return;

            this.logger.log(`📈 Procesando afinidad para stream válido: ${song.title} (User: ${userId})`);

            // 1. Impactar Artista
            if (song.artistId) {
                await this.updateScore(
                    userId,
                    song.artistId,
                    AffinityEntityType.ARTIST,
                    this.WEIGHTS.PLAY.ARTIST,
                );
            }

            // 2. Impactar Género Principal
            if (song.genreId) {
                await this.updateScore(
                    userId,
                    song.genreId,
                    AffinityEntityType.GENRE,
                    this.WEIGHTS.PLAY.GENRE,
                );
            }

            // TODO: Impactar sub-géneros si existen en song.genres array
        } catch (e) {
            this.logger.error(`Error procesando afinidad de stream: ${e.message}`, e.stack);
        }
    }

    /**
     * Procesa un skip rápido (< 5s)
     */
    async processSkip(userId: string, songId: string, secondsPlayed: number) {
        try {
            const song = await this.getSongWithRelations(songId);
            if (!song) return;

            this.logger.log(`📉 Procesando penalización por skip (${secondsPlayed}s): ${song.title} (User: ${userId})`);

            // 1. Penalizar Artista
            if (song.artistId) {
                await this.updateScore(
                    userId,
                    song.artistId,
                    AffinityEntityType.ARTIST,
                    this.WEIGHTS.SKIP.ARTIST,
                );
            }

            // 2. Penalizar Género
            if (song.genreId) {
                await this.updateScore(
                    userId,
                    song.genreId,
                    AffinityEntityType.GENRE,
                    this.WEIGHTS.SKIP.GENRE,
                );
            }
        } catch (e) {
            this.logger.error(`Error procesando afinidad de skip: ${e.message}`, e.stack);
        }
    }

    /**
     * Actualiza (Upsert) el puntaje de afinidad
     */
    private async updateScore(
        userId: string,
        entityId: string,
        type: AffinityEntityType,
        delta: number,
    ) {
        // Intentar buscar registro existente
        let affinity = await this.affinityRepository.findOne({
            where: { userId, entityId, entityType: type },
        });

        if (affinity) {
            // Actualizar existente
            affinity.score += delta;
            affinity.interactionCount += 1;
            // Evitar que el score se vaya al infinito negativo o positivo si se desea (opcional)
            // Por ahora dejamos libre.
        } else {
            // Crear nuevo
            affinity = this.affinityRepository.create({
                userId,
                entityId,
                entityType: type,
                score: delta,
                interactionCount: 1,
            });
        }

        await this.affinityRepository.save(affinity);
        // this.logger.debug(`Score actualizado: ${type} ${entityId} = ${affinity.score}`);
    }

    private async getSongWithRelations(songId: string): Promise<Song | null> {
        return this.songRepository.findOne({
            where: { id: songId },
            select: ['id', 'artistId', 'genreId', 'title', 'genres'], // Solo los campos necesarios
        });
    }
}
