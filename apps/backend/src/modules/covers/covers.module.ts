import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { CoversController } from './covers.controller';
import { CoversService } from './covers.service';
import { CoversStorageService } from './covers-storage.service';
import { FileValidationService } from '../../common/services/file-validation.service';
import { ImageProcessingService } from '../../common/services/image-processing.service';

@Module({
  imports: [ConfigModule],
  controllers: [CoversController],
  providers: [CoversService, CoversStorageService, FileValidationService, ImageProcessingService],
  exports: [CoversService, CoversStorageService],
})
export class CoversModule {}

