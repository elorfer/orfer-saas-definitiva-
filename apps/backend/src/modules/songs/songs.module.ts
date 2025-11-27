import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MulterModule } from '@nestjs/platform-express';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { BullModule } from '@nestjs/bull';
import { RecommendationModule } from '../recommendations/recommendation.module';

import { SongsController } from './songs.controller';
import { PublicSongsController } from './public-songs.controller';
import { SongsService } from './songs.service';
import { UploadOrchestratorService } from './upload-orchestrator.service';
import { UploadProcessorService } from './upload-processor.service';
import { CompensationService } from './compensation.service';
import { UploadProcessor } from './upload.processor';
import { LocalStorageService } from './local-storage.service';
import { CoversStorageService } from '../covers/covers-storage.service';
import { FileValidationService } from '../../common/services/file-validation.service';
import { AudioMetadataService } from '../../common/services/audio-metadata.service';
import { ImageProcessingService } from '../../common/services/image-processing.service';
import { Song } from '../../common/entities/song.entity';
import { SongUpload } from '../../common/entities/song-upload.entity';
import { Artist } from '../../common/entities/artist.entity';
import { Album } from '../../common/entities/album.entity';
import { Genre } from '../../common/entities/genre.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Song, SongUpload, Artist, Album, Genre]),
    RecommendationModule,
    ConfigModule,
    MulterModule.register({
      limits: {
        fileSize: 100 * 1024 * 1024, // 100MB
      },
      preservePath: false,
    }),
    // Configurar cola de BullMQ para procesamiento asíncrono
    BullModule.registerQueueAsync({
      name: 'song-upload',
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => {
        // Priorizar REDIS_URL si está disponible (para Docker)
        const redisUrl = configService.get<string>('REDIS_URL');
        
        let redisConfig: any = {
          maxRetriesPerRequest: null,
          enableReadyCheck: false,
        };
        
        if (redisUrl) {
          // Parsear REDIS_URL (formato: redis://[password@]host:port)
          const url = new URL(redisUrl);
          redisConfig.host = url.hostname;
          redisConfig.port = parseInt(url.port) || 6379;
          if (url.password) {
            redisConfig.password = url.password;
          }
        } else {
          // Fallback a REDIS_HOST y REDIS_PORT
          redisConfig.host = configService.get<string>('REDIS_HOST') || 'localhost';
          redisConfig.port = configService.get<number>('REDIS_PORT') || 6379;
          
          const password = configService.get<string>('REDIS_PASSWORD');
          if (password) {
            redisConfig.password = password;
          }
        }
        
        return {
          redis: redisConfig,
          defaultJobOptions: {
            attempts: 3,
            backoff: {
              type: 'exponential',
              delay: 5000,
            },
            removeOnComplete: {
              age: 24 * 3600, // 24 horas
              count: 1000,
            },
            removeOnFail: {
              age: 7 * 24 * 3600, // 7 días
            },
          },
        };
      },
      inject: [ConfigService],
    }),
  ],
  controllers: [SongsController, PublicSongsController],
  providers: [
    SongsService,
    UploadOrchestratorService,
    UploadProcessorService,
    CompensationService,
    UploadProcessor,
    LocalStorageService,
    CoversStorageService,
    FileValidationService,
    AudioMetadataService,
    ImageProcessingService,
  ],
  exports: [SongsService, LocalStorageService, UploadOrchestratorService],
})
export class SongsModule {}









