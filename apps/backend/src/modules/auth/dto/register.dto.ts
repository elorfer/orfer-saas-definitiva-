import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength, MaxLength, IsOptional, IsEnum } from 'class-validator';
import { UserRole } from '../../../common/entities/user.entity';

export class RegisterDto {
  @ApiProperty({ example: 'usuario@ejemplo.com', description: 'Email del usuario' })
  @IsEmail({}, { message: 'Debe proporcionar un email válido' })
  email: string;

  @ApiProperty({ example: 'usuario123', description: 'Nombre de usuario único' })
  @IsString({ message: 'El nombre de usuario debe ser una cadena de texto' })
  @MinLength(3, { message: 'El nombre de usuario debe tener al menos 3 caracteres' })
  @MaxLength(50, { message: 'El nombre de usuario no puede exceder 50 caracteres' })
  username: string;

  @ApiProperty({ example: 'ContraseñaSegura123!', description: 'Contraseña del usuario' })
  @IsString({ message: 'La contraseña debe ser una cadena de texto' })
  @MinLength(8, { message: 'La contraseña debe tener al menos 8 caracteres' })
  password: string;

  @ApiProperty({ example: 'Juan', description: 'Nombre del usuario' })
  @IsString({ message: 'El nombre debe ser una cadena de texto' })
  @MinLength(2, { message: 'El nombre debe tener al menos 2 caracteres' })
  @MaxLength(100, { message: 'El nombre no puede exceder 100 caracteres' })
  firstName: string;

  @ApiProperty({ example: 'Pérez', description: 'Apellido del usuario' })
  @IsString({ message: 'El apellido debe ser una cadena de texto' })
  @MinLength(2, { message: 'El apellido debe tener al menos 2 caracteres' })
  @MaxLength(100, { message: 'El apellido no puede exceder 100 caracteres' })
  lastName: string;

  @ApiProperty({ 
    example: 'artist', 
    description: 'Rol del usuario', 
    enum: UserRole,
    required: false 
  })
  @IsOptional()
  @IsEnum(UserRole, { message: 'El rol debe ser admin, artist o user' })
  role?: UserRole;

  @ApiProperty({ 
    example: 'Mi Nombre Artístico', 
    description: 'Nombre artístico (requerido si el rol es artist)',
    required: false 
  })
  @IsOptional()
  @IsString({ message: 'El nombre artístico debe ser una cadena de texto' })
  @MaxLength(100, { message: 'El nombre artístico no puede exceder 100 caracteres' })
  stageName?: string;
}









