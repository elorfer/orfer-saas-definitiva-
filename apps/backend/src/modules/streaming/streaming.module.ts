import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { StreamingController } from './streaming.controller';
import { StreamingService } from './streaming.service';
import { Song } from '../../common/entities/song.entity';
import { User } from '../../common/entities/user.entity';
import { PlayHistory } from '../../common/entities/play-history.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Song, User, PlayHistory])],
  controllers: [StreamingController],
  providers: [StreamingService],
  exports: [StreamingService],
})
export class StreamingModule {}









