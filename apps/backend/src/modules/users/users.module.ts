import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User } from '../../common/entities/user.entity';
import { Artist } from '../../common/entities/artist.entity';
import { ArtistsModule } from '../artists/artists.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, Artist]),
    ArtistsModule, // Importar para usar ArtistsService
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}









