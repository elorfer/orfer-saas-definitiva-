import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { ArtistsController } from './artists.controller';
import { PublicArtistsController } from './public-artists.controller';
import { ArtistsService } from './artists.service';
import { Artist } from '../../common/entities/artist.entity';
import { User } from '../../common/entities/user.entity';
import { Song } from '../../common/entities/song.entity';
import { Album } from '../../common/entities/album.entity';
import { CoversModule } from '../covers/covers.module';
import { FeaturedModule } from '../featured/featured.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Artist, User, Song, Album]),
    CoversModule,
    forwardRef(() => FeaturedModule),
  ],
  controllers: [ArtistsController, PublicArtistsController],
  providers: [ArtistsService],
  exports: [ArtistsService],
})
export class ArtistsModule {}




