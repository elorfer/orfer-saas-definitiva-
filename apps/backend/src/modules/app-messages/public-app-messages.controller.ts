import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';

import { AppMessagesService } from './app-messages.service';

@ApiTags('public-app-messages')
@Controller('public/app-messages')
export class PublicAppMessagesController {
  constructor(private readonly appMessagesService: AppMessagesService) {}

  @Get('home')
  @ApiOperation({ summary: 'Obtener el mensaje activo del inicio (público)' })
  async getHomeMessage() {
    const message = await this.appMessagesService.getLatestHomeMessage({
      onlyActive: true,
    });

    return {
      message: message?.message ?? null,
      isActive: message?.isActive ?? false,
      updatedAt: message?.updatedAt ?? message?.publishedAt ?? null,
    };
  }
}







