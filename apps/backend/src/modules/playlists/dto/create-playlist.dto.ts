import { IsString, IsOptional, IsBoolean, IsArray, IsUUID } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreatePlaylistDto {
  @ApiProperty({ description: 'Título de la playlist', example: 'Mis Canciones Favoritas' })
  @IsString()
  name: string;

  @ApiPropertyOptional({ description: 'Descripción de la playlist', example: 'Una colección de mis canciones favoritas' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ description: 'URL de la portada de la playlist' })
  @IsOptional()
  @IsString()
  coverArtUrl?: string;

  @ApiPropertyOptional({ description: 'IDs de las canciones a incluir en la playlist', type: [String] })
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  songIds?: string[];

  @ApiPropertyOptional({ description: 'Marcar playlist como destacada', default: false })
  @IsOptional()
  @IsBoolean()
  isFeatured?: boolean;
}

