import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';

import { AdsController } from './ads.controller';
import { PublicAdsController } from './public-ads.controller';
import { AdsService } from './ads.service';
import { AdsLocalStorageService, IAdsStorageService } from './ads-storage.service';
import { AudioAd } from '../../common/entities/audio-ad.entity';
import { AdPlayLog } from '../../common/entities/ad-play-log.entity';
import { UploadModule } from '../upload/upload.module';
import { FileValidationService } from '../../common/services/file-validation.service';
import { AudioMetadataService } from '../../common/services/audio-metadata.service';
import { ImageProcessingService } from '../../common/services/image-processing.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([AudioAd, AdPlayLog]),
    ConfigModule,
    UploadModule,
  ],
  controllers: [AdsController, PublicAdsController],
  providers: [
    AdsService,
    // Servicio de almacenamiento: usar LocalStorage por defecto
    // Para migrar a S3, cambiar AdsLocalStorageService por AdsS3StorageService
    {
      provide: 'IAdsStorageService',
      useClass: AdsLocalStorageService,
    },
    AdsLocalStorageService,
    FileValidationService,
    AudioMetadataService,
    ImageProcessingService,
  ],
  exports: [AdsService],
})
export class AdsModule {}




