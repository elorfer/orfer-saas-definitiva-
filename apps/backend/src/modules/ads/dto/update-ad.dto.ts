import { PartialType } from '@nestjs/mapped-types';
import { CreateAdDto } from './create-ad.dto';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateAdDto extends PartialType(CreateAdDto) {
  @ApiPropertyOptional({ description: 'Actualizar contador de reproducciones' })
  totalPlays?: number;

  @ApiPropertyOptional({ description: 'Actualizar contador de clicks' })
  totalClicks?: number;
}

