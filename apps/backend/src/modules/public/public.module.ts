import { Module } from '@nestjs/common';
import { PublicController } from './public.controller';
import { ArtistsModule } from '../artists/artists.module';
import { SongsModule } from '../songs/songs.module';
import { PlaylistsModule } from '../playlists/playlists.module';

@Module({
  imports: [ArtistsModule, SongsModule, PlaylistsModule],
  controllers: [PublicController],
})
export class PublicModule {}






















