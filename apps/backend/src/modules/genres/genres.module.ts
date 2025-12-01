import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { GenresController } from './genres.controller';
import { GenresService } from './genres.service';
import { Genre } from '../../common/entities/genre.entity';

/**
 * Módulo para gestionar géneros musicales
 * Proporciona operaciones CRUD completas para géneros
 */
@Module({
  imports: [TypeOrmModule.forFeature([Genre])],
  controllers: [GenresController],
  providers: [GenresService],
  exports: [GenresService], // Exportar para que otros módulos puedan usar el servicio
})
export class GenresModule {}














