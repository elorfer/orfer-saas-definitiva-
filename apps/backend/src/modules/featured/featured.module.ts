import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { FeaturedController } from './featured.controller';
import { PublicFeaturedController } from './public-featured.controller';
import { FeaturedService } from './featured.service';
import { Song } from '../../common/entities/song.entity';
import { Artist } from '../../common/entities/artist.entity';
import { Playlist } from '../../common/entities/playlist.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Song, Artist, Playlist])],
  controllers: [FeaturedController, PublicFeaturedController],
  providers: [FeaturedService],
  exports: [FeaturedService],
})
export class FeaturedModule {}

