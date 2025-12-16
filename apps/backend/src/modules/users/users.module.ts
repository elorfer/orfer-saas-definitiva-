import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User } from '../../common/entities/user.entity';
import { Artist } from '../../common/entities/artist.entity';
import { ArtistsModule } from '../artists/artists.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, Artist]),
    ArtistsModule, // Importar para usar ArtistsService
    forwardRef(() => RealtimeModule), // Importar para notificaciones WebSocket
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}









