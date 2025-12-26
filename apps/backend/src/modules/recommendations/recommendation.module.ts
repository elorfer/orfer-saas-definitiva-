import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RecommendationService } from './recommendation.service';
import { Song } from '../../common/entities/song.entity';
import { PlayHistory } from '../../common/entities/play-history.entity';
import { Genre } from '../../common/entities/genre.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Song, PlayHistory, Genre]),
  ],
  providers: [RecommendationService],
  exports: [RecommendationService],
})
export class RecommendationModule {}


































