import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsUrl,
  IsInt,
  IsEnum,
  IsArray,
  IsBoolean,
  Min,
  Max,
  ValidateIf,
  IsDateString,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { AdStatus, AdTargeting } from '../../../common/entities/audio-ad.entity';

export class CreateAdDto {
  @ApiProperty({ description: 'Título del anuncio', example: 'Nueva App de Música' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiPropertyOptional({ description: 'Descripción del anuncio' })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({ description: 'URL del archivo de audio (se puede subir después)', example: 'https://cdn.example.com/ads/audio.mp3' })
  @ValidateIf((o) => o.audioUrl && o.audioUrl !== '')
  @IsUrl({ require_tld: false })
  @IsOptional()
  audioUrl?: string;

  @ApiPropertyOptional({ description: 'URL de la carátula del anuncio' })
  @ValidateIf((o) => o.coverImageUrl && o.coverImageUrl !== '')
  @IsUrl({ require_tld: false })
  @IsOptional()
  coverImageUrl?: string;

  @ApiProperty({ description: 'Nombre del anunciante', example: 'Tech Corp' })
  @IsString()
  @IsNotEmpty()
  advertiserName: string;

  @ApiPropertyOptional({ description: 'URL a abrir al hacer click en el anuncio' })
  @ValidateIf((o) => o.clickThroughUrl && o.clickThroughUrl !== '')
  @IsUrl({ require_tld: false })
  @IsOptional()
  clickThroughUrl?: string;

  @ApiProperty({ description: 'Duración del anuncio en segundos', example: 15, minimum: 5, maximum: 60 })
  @IsInt()
  @Min(5)
  @Max(60)
  durationSeconds: number;

  @ApiProperty({ description: 'Tamaño del archivo en bytes', example: 2048000 })
  @IsInt()
  @Min(0)
  fileSizeBytes: number;

  @ApiPropertyOptional({ description: 'Estado del anuncio', enum: AdStatus, default: AdStatus.DRAFT })
  @IsEnum(AdStatus)
  @IsOptional()
  status?: AdStatus;

  @ApiPropertyOptional({ description: 'Tipo de targeting', enum: AdTargeting, default: AdTargeting.ALL })
  @IsEnum(AdTargeting)
  @IsOptional()
  targeting?: AdTargeting;

  @ApiPropertyOptional({ description: 'Géneros objetivo (si targeting es GENRE)', type: [String] })
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  @ValidateIf((o) => o.targeting === AdTargeting.GENRE)
  targetGenres?: string[];

  @ApiPropertyOptional({ description: 'Artistas objetivo (si targeting es ARTIST)', type: [String] })
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  @ValidateIf((o) => o.targeting === AdTargeting.ARTIST)
  targetArtists?: string[];

  @ApiPropertyOptional({ description: 'Playlists objetivo (si targeting es PLAYLIST)', type: [String] })
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  @ValidateIf((o) => o.targeting === AdTargeting.PLAYLIST)
  targetPlaylists?: string[];

  @ApiPropertyOptional({ description: 'Frecuencia máxima por hora', example: 1, default: 1, minimum: 1, maximum: 10 })
  @IsInt()
  @Min(1)
  @Max(10)
  @IsOptional()
  frequencyPerHour?: number;

  @ApiPropertyOptional({ description: 'Límite máximo de reproducciones por día', example: 1000 })
  @IsInt()
  @Min(1)
  @IsOptional()
  maxPlaysPerDay?: number;

  @ApiPropertyOptional({ description: 'Fecha de inicio de la campaña (ISO 8601)' })
  @IsDateString()
  @IsOptional()
  startDate?: string;

  @ApiPropertyOptional({ description: 'Fecha de fin de la campaña (ISO 8601)' })
  @IsDateString()
  @IsOptional()
  endDate?: string;

  @ApiPropertyOptional({ description: 'Prioridad del anuncio (0-100)', example: 50, minimum: 0, maximum: 100, default: 0 })
  @IsInt()
  @Min(0)
  @Max(100)
  @IsOptional()
  priority?: number;

  @ApiPropertyOptional({ description: 'Si el anuncio puede ser saltado', default: true })
  @IsBoolean()
  @IsOptional()
  isSkippable?: boolean;

  @ApiPropertyOptional({ description: 'Segundos antes de permitir skip', example: 5, minimum: 0, maximum: 30, default: 5 })
  @IsInt()
  @Min(0)
  @Max(30)
  @IsOptional()
  skipAfterSeconds?: number;
}

