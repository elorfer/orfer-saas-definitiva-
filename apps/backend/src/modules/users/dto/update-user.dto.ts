import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength, MaxLength, IsOptional, IsEnum, IsBoolean } from 'class-validator';
import { UserRole, SubscriptionStatus } from '../../../common/entities/user.entity';

export class UpdateUserDto {
  @ApiProperty({ example: 'usuario@ejemplo.com', description: 'Email del usuario', required: false })
  @IsOptional()
  @IsEmail({}, { message: 'Debe proporcionar un email válido' })
  email?: string;

  @ApiProperty({ example: 'usuario123', description: 'Nombre de usuario único', required: false })
  @IsOptional()
  @IsString({ message: 'El nombre de usuario debe ser una cadena de texto' })
  @MinLength(3, { message: 'El nombre de usuario debe tener al menos 3 caracteres' })
  @MaxLength(50, { message: 'El nombre de usuario no puede exceder 50 caracteres' })
  username?: string;

  @ApiProperty({ example: 'Juan', description: 'Nombre del usuario', required: false })
  @IsOptional()
  @IsString({ message: 'El nombre debe ser una cadena de texto' })
  @MinLength(2, { message: 'El nombre debe tener al menos 2 caracteres' })
  @MaxLength(100, { message: 'El nombre no puede exceder 100 caracteres' })
  firstName?: string;

  @ApiProperty({ example: 'Pérez', description: 'Apellido del usuario', required: false })
  @IsOptional()
  @IsString({ message: 'El apellido debe ser una cadena de texto' })
  @MinLength(2, { message: 'El apellido debe tener al menos 2 caracteres' })
  @MaxLength(100, { message: 'El apellido no puede exceder 100 caracteres' })
  lastName?: string;

  @ApiProperty({ example: 'https://example.com/avatar.jpg', description: 'URL del avatar', required: false })
  @IsOptional()
  @IsString({ message: 'La URL del avatar debe ser una cadena de texto' })
  avatarUrl?: string;

  @ApiProperty({ 
    example: 'user', 
    description: 'Rol del usuario', 
    enum: UserRole,
    required: false 
  })
  @IsOptional()
  @IsEnum(UserRole, { message: 'El rol debe ser admin, artist o user' })
  role?: UserRole;

  @ApiProperty({ 
    example: 'active', 
    description: 'Estado de suscripción', 
    enum: SubscriptionStatus,
    required: false 
  })
  @IsOptional()
  @IsEnum(SubscriptionStatus, { message: 'El estado de suscripción debe ser válido' })
  subscriptionStatus?: SubscriptionStatus;

  @ApiProperty({ example: true, description: 'Usuario verificado', required: false })
  @IsOptional()
  @IsBoolean({ message: 'El estado de verificación debe ser un booleano' })
  isVerified?: boolean;

  @ApiProperty({ example: true, description: 'Usuario activo', required: false })
  @IsOptional()
  @IsBoolean({ message: 'El estado activo debe ser un booleano' })
  isActive?: boolean;
}









