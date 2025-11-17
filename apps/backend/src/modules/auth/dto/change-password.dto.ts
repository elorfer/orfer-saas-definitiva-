import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @ApiProperty({ example: 'ContraseñaActual123!', description: 'Contraseña actual' })
  @IsString({ message: 'La contraseña actual debe ser una cadena de texto' })
  @MinLength(1, { message: 'La contraseña actual es requerida' })
  oldPassword: string;

  @ApiProperty({ example: 'NuevaContraseñaSegura123!', description: 'Nueva contraseña' })
  @IsString({ message: 'La nueva contraseña debe ser una cadena de texto' })
  @MinLength(8, { message: 'La nueva contraseña debe tener al menos 8 caracteres' })
  newPassword: string;
}









