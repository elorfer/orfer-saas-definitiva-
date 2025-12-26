import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DiscoveryController } from './discovery.controller';
import { DiscoveryService } from './discovery.service';
import { Song } from '../../common/entities/song.entity';

/**
 * 🔮 DISCOVERY MODULE - SIMPLIFICADO
 * 
 * Motor de recomendación basado en géneros.
 * Simple, rápido y confiable.
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([Song]),
  ],
  controllers: [DiscoveryController],
  providers: [DiscoveryService],
  exports: [DiscoveryService],
})
export class DiscoveryModule {}
