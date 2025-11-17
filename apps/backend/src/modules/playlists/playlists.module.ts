import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MulterModule } from '@nestjs/platform-express';

import { PlaylistsController } from './playlists.controller';
import { PublicPlaylistsController } from './public-playlists.controller';
import { PlaylistsService } from './playlists.service';
import { Playlist } from '../../common/entities/playlist.entity';
import { User } from '../../common/entities/user.entity';
import { Song } from '../../common/entities/song.entity';
import { PlaylistSong } from '../../common/entities/playlist-song.entity';
import { CoversStorageService } from '../covers/covers-storage.service';
import { FileValidationService } from '../../common/services/file-validation.service';
import { ImageProcessingService } from '../../common/services/image-processing.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Playlist, User, Song, PlaylistSong]),
    MulterModule.register({
      limits: {
        fileSize: 10 * 1024 * 1024, // 10MB
      },
    }),
  ],
  controllers: [PlaylistsController, PublicPlaylistsController],
  providers: [PlaylistsService, CoversStorageService, FileValidationService, ImageProcessingService],
  exports: [PlaylistsService],
})
export class PlaylistsModule {}









