import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength } from 'class-validator';

export class ResetPasswordDto {
  @ApiProperty({ example: 'token123456', description: 'Token de recuperación' })
  @IsString({ message: 'El token debe ser una cadena de texto' })
  token: string;

  @ApiProperty({ example: 'NuevaContraseña123!', description: 'Nueva contraseña' })
  @IsString({ message: 'La contraseña debe ser una cadena de texto' })
  @MinLength(8, { message: 'La contraseña debe tener al menos 8 caracteres' })
  newPassword: string;
}

