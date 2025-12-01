import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { FavoritesController } from './favorites.controller';
import { FavoritesService } from './favorites.service';
import { SongLike } from '../../common/entities/song-like.entity';
import { Song } from '../../common/entities/song.entity';
import { User } from '../../common/entities/user.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([SongLike, Song, User]),
  ],
  controllers: [FavoritesController],
  providers: [FavoritesService],
  exports: [FavoritesService],
})
export class FavoritesModule {}









