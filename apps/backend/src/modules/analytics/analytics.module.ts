import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';
import { Song } from '../../common/entities/song.entity';
import { Artist } from '../../common/entities/artist.entity';
import { StreamingStats } from '../../common/entities/streaming-stats.entity';
import { PlayHistory } from '../../common/entities/play-history.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Song, Artist, StreamingStats, PlayHistory])],
  controllers: [AnalyticsController],
  providers: [AnalyticsService],
  exports: [AnalyticsService],
})
export class AnalyticsModule {}









