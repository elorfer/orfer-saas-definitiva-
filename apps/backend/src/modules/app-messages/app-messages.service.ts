import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { AppMessage, AppMessageType } from '../../common/entities/app-message.entity';
import { PublishHomeMessageDto } from './dto/publish-home-message.dto';

@Injectable()
export class AppMessagesService {
  private readonly logger = new Logger(AppMessagesService.name);

  constructor(
    @InjectRepository(AppMessage)
    private readonly appMessageRepository: Repository<AppMessage>,
  ) {}

  async publishHomeMessage(dto: PublishHomeMessageDto, userId?: string): Promise<AppMessage> {
    const message = dto.message.trim();
    const isActive = dto.isActive ?? true;

    if (isActive) {
      await this.appMessageRepository
        .createQueryBuilder()
        .update(AppMessage)
        .set({ isActive: false })
        .where('type = :type', { type: AppMessageType.HOME_BANNER })
        .execute();
    }

    const entity = this.appMessageRepository.create({
      type: AppMessageType.HOME_BANNER,
      message,
      isActive,
      createdBy: userId,
      publishedAt: new Date(),
    });

    const saved = await this.appMessageRepository.save(entity);
    this.logger.log(`[publishHomeMessage] Nuevo mensaje publicado (activo=${isActive}): "${message}"`);
    return saved;
  }

  async getLatestHomeMessage(options?: { onlyActive?: boolean }): Promise<AppMessage | null> {
    const where: Partial<AppMessage> = { type: AppMessageType.HOME_BANNER };
    if (options?.onlyActive) {
      where.isActive = true;
    }

    return this.appMessageRepository.findOne({
      where,
      order: {
        publishedAt: 'DESC',
        updatedAt: 'DESC',
        createdAt: 'DESC',
      },
    });
  }

  async updateHomeMessageStatus(id: string, isActive: boolean): Promise<AppMessage> {
    const message = await this.appMessageRepository.findOne({
      where: { id, type: AppMessageType.HOME_BANNER },
    });

    if (!message) {
      throw new NotFoundException('Mensaje no encontrado');
    }

    if (isActive) {
      await this.appMessageRepository
        .createQueryBuilder()
        .update(AppMessage)
        .set({ isActive: false })
        .where('type = :type', { type: AppMessageType.HOME_BANNER })
        .execute();
    }

    message.isActive = isActive;
    const saved = await this.appMessageRepository.save(message);
    this.logger.log(`[updateHomeMessageStatus] Mensaje ${id} marcado como ${isActive ? 'activo' : 'inactivo'}`);
    return saved;
  }

  async disableAllHomeMessages(): Promise<void> {
    await this.appMessageRepository
      .createQueryBuilder()
      .update(AppMessage)
      .set({ isActive: false })
      .where('type = :type', { type: AppMessageType.HOME_BANNER })
      .execute();
    this.logger.log('[disableAllHomeMessages] Todos los mensajes de inicio fueron desactivados');
  }
}

