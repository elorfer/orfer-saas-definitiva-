import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, IsArray, IsEnum, IsBoolean } from 'class-validator';
import { SongStatus } from '../../../common/entities/song.entity';

export class UpdateSongDto {
  @ApiProperty({ description: 'Título de la canción', required: false })
  @IsOptional()
  @IsString()
  title?: string;

  @ApiProperty({ description: 'ID del artista', required: false })
  @IsOptional()
  @IsString()
  artistId?: string;

  @ApiProperty({ description: 'ID del álbum', required: false })
  @IsOptional()
  @IsString()
  albumId?: string;

  @ApiProperty({ description: 'ID del género (legacy)', required: false })
  @IsOptional()
  @IsString()
  genreId?: string;

  @ApiProperty({ 
    description: 'Array de géneros musicales', 
    type: [String],
    required: false,
    example: ['Reggaeton', 'Trap Latino']
  })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  genres?: string[];

  @ApiProperty({ description: 'Estado de la canción', enum: SongStatus, required: false })
  @IsOptional()
  @IsEnum(SongStatus)
  status?: SongStatus;

  @ApiProperty({ description: 'Indica si es explícita', required: false })
  @IsOptional()
  @IsBoolean()
  isExplicit?: boolean;

  @ApiProperty({ description: 'Fecha de lanzamiento', required: false })
  @IsOptional()
  releaseDate?: Date;
}





