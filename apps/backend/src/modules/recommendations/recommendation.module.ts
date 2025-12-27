import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RecommendationService } from './recommendation.service';
import { Song } from '../../common/entities/song.entity';
import { PlayHistory } from '../../common/entities/play-history.entity';
import { Genre } from '../../common/entities/genre.entity';
import { SongLike } from '../../common/entities/song-like.entity';
import { ArtistFollower } from '../../common/entities/artist-follower.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Song, PlayHistory, Genre, SongLike, ArtistFollower]),
  ],
  providers: [RecommendationService],
  exports: [RecommendationService],
})
export class RecommendationModule { }


































