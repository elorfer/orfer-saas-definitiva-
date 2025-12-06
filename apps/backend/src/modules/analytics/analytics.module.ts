import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';
import { Song } from '../../common/entities/song.entity';
import { Artist } from '../../common/entities/artist.entity';
import { StreamingStats } from '../../common/entities/streaming-stats.entity';
import { PlayHistory } from '../../common/entities/play-history.entity';
import { Genre } from '../../common/entities/genre.entity';
import { User } from '../../common/entities/user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Song, Artist, StreamingStats, PlayHistory, Genre, User])],
  controllers: [AnalyticsController],
  providers: [AnalyticsService],
  exports: [AnalyticsService],
})
export class AnalyticsModule {}









