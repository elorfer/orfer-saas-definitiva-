import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MulterModule } from '@nestjs/platform-express';
import { TypeOrmModule } from '@nestjs/typeorm';

import { UploadController } from './upload.controller';
import { UploadService } from './upload.service';
import { S3Service } from './s3.service';
import { User } from '../../common/entities/user.entity';
import { Artist } from '../../common/entities/artist.entity';

@Module({
  imports: [
    ConfigModule,
    TypeOrmModule.forFeature([User, Artist]),
    MulterModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        limits: {
          fileSize: 100 * 1024 * 1024, // 100MB
        },
        fileFilter: (req, file, callback) => {
          // Validar tipos de archivo permitidos
          const allowedMimeTypes = [
            'audio/mpeg',
            'audio/mp3',
            'audio/wav',
            'audio/flac',
            'audio/aac',
            'audio/ogg',
            'image/jpeg',
            'image/png',
            'image/webp',
          ];

          if (allowedMimeTypes.includes(file.mimetype)) {
            callback(null, true);
          } else {
            callback(new Error('Tipo de archivo no permitido'), false);
          }
        },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [UploadController],
  providers: [UploadService, S3Service],
  exports: [UploadService, S3Service],
})
export class UploadModule {}









