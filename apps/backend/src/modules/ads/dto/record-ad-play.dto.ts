
import { IsBoolean, IsNumber, IsOptional, IsString, IsNotEmpty, IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RecordAdPlayDto {
    @ApiProperty({ description: 'Duración reproducida en segundos' })
    @IsNumber()
    @IsNotEmpty()
    durationPlayed: number;

    @ApiProperty({ description: 'Indica si el anuncio se completó' })
    @IsBoolean()
    @IsNotEmpty()
    wasCompleted: boolean;

    @ApiProperty({ description: 'Indica si el anuncio fue saltado' })
    @IsBoolean()
    @IsNotEmpty()
    wasSkipped: boolean;

    @ApiProperty({ description: 'Género musical del contexto (opcional)', required: false })
    @IsString()
    @IsOptional()
    genre?: string;

    @ApiProperty({ description: 'Artista del contexto (opcional)', required: false })
    @IsString()
    @IsOptional()
    artist?: string;

    @ApiProperty({ description: 'ID de la playlist (opcional)', required: false })
    @IsString()
    @IsOptional()
    @IsUUID()
    playlistId?: string;
}
