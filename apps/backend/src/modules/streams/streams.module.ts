import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import { StreamsController } from './streams.controller';
import { StreamsService } from './streams.service';
import { Song } from '../../common/entities/song.entity';
import { Artist } from '../../common/entities/artist.entity';
import { Stream } from '../../common/entities/stream.entity';
import { UserListeningSession } from '../../common/entities/user-listening-session.entity';

@Module({
  imports: [
    ConfigModule,
    TypeOrmModule.forFeature([
      Song,
      Artist,
      Stream,
      UserListeningSession,
    ]),
  ],
  controllers: [StreamsController],
  providers: [
    {
      provide: 'REDIS_CLIENT',
      useFactory: (configService: ConfigService) => {
        const redisUrl = configService.get<string>('REDIS_URL');
        
        if (redisUrl) {
          return new Redis(redisUrl, {
            retryStrategy: (times) => {
              const delay = Math.min(times * 50, 2000);
              return delay;
            },
            maxRetriesPerRequest: 3,
          });
        }

        return new Redis({
          host: configService.get<string>('REDIS_HOST', 'localhost'),
          port: parseInt(configService.get<string>('REDIS_PORT', '6379')),
          password: configService.get<string>('REDIS_PASSWORD'),
          db: parseInt(configService.get<string>('REDIS_DB', '0')),
          retryStrategy: (times) => {
            const delay = Math.min(times * 50, 2000);
            return delay;
          },
          maxRetriesPerRequest: 3,
        });
      },
      inject: [ConfigService],
    },
    StreamsService,
  ],
  exports: [StreamsService],
})
export class StreamsModule {}

