import { IsString, IsNotEmpty, IsNumber, Min, Max } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class TrackProgressDto {
  @ApiProperty({ description: 'ID de la canción', example: 'uuid-song-id' })
  @IsString()
  @IsNotEmpty()
  songId: string;

  @ApiProperty({ description: 'Progreso actual en milisegundos', example: 45000, minimum: 0 })
  @IsNumber()
  @Min(0)
  progressMs: number;

  @ApiProperty({ description: 'Duración total de la canción en milisegundos', example: 210000 })
  @IsNumber()
  @Min(0)
  durationMs: number;

  @ApiProperty({ description: 'Volumen del reproductor (0-1)', example: 0.8, required: false })
  @IsNumber()
  @Min(0)
  @Max(1)
  volume?: number;

  @ApiProperty({ description: 'Si la app está en primer plano', example: true, required: false })
  isForeground?: boolean;
}




















