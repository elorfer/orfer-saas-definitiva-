import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RecommendationService } from './recommendation.service';
import { Song } from '../../common/entities/song.entity';
import { PlayHistory } from '../../common/entities/play-history.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Song, PlayHistory]),
  ],
  providers: [RecommendationService],
  exports: [RecommendationService],
})
export class RecommendationModule {}


