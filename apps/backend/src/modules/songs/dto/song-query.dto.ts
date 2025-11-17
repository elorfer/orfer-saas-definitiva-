import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsInt, Min, Max, IsBoolean } from 'class-validator';
import { Type } from 'class-transformer';

/**
 * DTO para query parameters de búsqueda de canciones
 */
export class SongQueryDto {
  @ApiProperty({ description: 'Número de página', required: false, default: 1, minimum: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiProperty({ description: 'Elementos por página', required: false, default: 20, minimum: 1, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  @ApiProperty({ description: 'Filtrar solo destacadas', required: false, default: false })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  featured?: boolean = false;

  @ApiProperty({ description: 'ID del artista para filtrar', required: false })
  @IsOptional()
  artistId?: string;

  @ApiProperty({ description: 'ID del género para filtrar', required: false })
  @IsOptional()
  genreId?: string;

  @ApiProperty({ description: 'Término de búsqueda (título o artista)', required: false })
  @IsOptional()
  search?: string;
}
