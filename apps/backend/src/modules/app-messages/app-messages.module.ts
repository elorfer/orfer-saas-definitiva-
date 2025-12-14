import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AppMessage } from '../../common/entities/app-message.entity';
import { AppMessagesService } from './app-messages.service';
import { AppMessagesController } from './app-messages.controller';
import { PublicAppMessagesController } from './public-app-messages.controller';

@Module({
  imports: [TypeOrmModule.forFeature([AppMessage])],
  controllers: [AppMessagesController, PublicAppMessagesController],
  providers: [AppMessagesService],
  exports: [AppMessagesService],
})
export class AppMessagesModule {}





