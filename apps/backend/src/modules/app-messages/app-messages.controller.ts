import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';

import { AppMessagesService } from './app-messages.service';
import { PublishHomeMessageDto } from './dto/publish-home-message.dto';
import { UpdateHomeMessageStatusDto } from './dto/update-home-message-status.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../../common/entities/user.entity';

@ApiTags('app-messages')
@Controller('app-messages')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class AppMessagesController {
  constructor(private readonly appMessagesService: AppMessagesService) {}

  @Get('home')
  @ApiOperation({ summary: 'Obtener el último mensaje de inicio (admin)' })
  async getHomeMessage() {
    const message = await this.appMessagesService.getLatestHomeMessage();
    return {
      id: message?.id ?? null,
      message: message?.message ?? null,
      isActive: message?.isActive ?? false,
      publishedAt: message?.publishedAt ?? null,
      updatedAt: message?.updatedAt ?? message?.publishedAt ?? null,
    };
  }

  @Post('home')
  @ApiOperation({ summary: 'Publicar un nuevo mensaje de inicio' })
  @ApiResponse({ status: 201, description: 'Mensaje publicado correctamente' })
  async publishHomeMessage(
    @Body() dto: PublishHomeMessageDto,
    @CurrentUser() user: User,
  ) {
    return this.appMessagesService.publishHomeMessage(dto, user?.id);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: 'Activar o desactivar un mensaje de inicio' })
  async updateHomeMessageStatus(
    @Param('id') id: string,
    @Body() dto: UpdateHomeMessageStatusDto,
  ) {
    return this.appMessagesService.updateHomeMessageStatus(id, dto.isActive);
  }

  @Post('home/disable')
  @ApiOperation({ summary: 'Desactivar todos los mensajes de inicio' })
  async disableAll() {
    await this.appMessagesService.disableAllHomeMessages();
    return { success: true };
  }
}





