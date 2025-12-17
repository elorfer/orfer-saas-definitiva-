import { IsInt, Min, Max, IsOptional, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateAdFrequencyDto {
  @ApiProperty({
    description: 'Número de canciones entre anuncios',
    example: 3,
    minimum: 1,
    maximum: 20,
  })
  @IsInt()
  @Min(1, { message: 'La frecuencia mínima es 1 canción' })
  @Max(20, { message: 'La frecuencia máxima es 20 canciones' })
  value: number;
}

export class UpdateSettingDto {
  @ApiProperty({
    description: 'Valor numérico de la configuración',
    example: 3,
  })
  @IsInt()
  value: number;

  @ApiProperty({
    description: 'Descripción opcional de la configuración',
    required: false,
  })
  @IsOptional()
  @IsString()
  description?: string;
}

