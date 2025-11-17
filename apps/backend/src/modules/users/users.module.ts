import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User } from '../../common/entities/user.entity';
import { Artist } from '../../common/entities/artist.entity';

@Module({
  imports: [TypeOrmModule.forFeature([User, Artist])],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}









