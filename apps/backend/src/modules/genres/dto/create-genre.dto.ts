import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, MaxLength, Matches } from 'class-validator';

/**
 * DTO para crear un nuevo género musical
 */
export class CreateGenreDto {
  @ApiProperty({
    description: 'Nombre del género musical',
    example: 'Reggaeton',
    maxLength: 50,
  })
  @IsString()
  @IsNotEmpty({ message: 'El nombre del género es requerido' })
  @MaxLength(50, { message: 'El nombre del género no puede exceder 50 caracteres' })
  name: string;

  @ApiProperty({
    description: 'Descripción del género musical',
    example: 'Género musical originario de Puerto Rico que combina reggae y hip hop',
    required: false,
  })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiProperty({
    description: 'Color hexadecimal para representar el género (formato: #RRGGBB)',
    example: '#FF5733',
    required: false,
    pattern: '^#[0-9A-Fa-f]{6}$',
  })
  @IsString()
  @IsOptional()
  @Matches(/^#[0-9A-Fa-f]{6}$/, {
    message: 'El color debe ser un código hexadecimal válido (ej: #FF5733)',
  })
  colorHex?: string;
}





