import { IsBoolean, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class PublishHomeMessageDto {
  @IsString()
  @IsNotEmpty({ message: 'El mensaje no puede estar vacío' })
  @MaxLength(240, { message: 'El mensaje debe tener máximo 240 caracteres' })
  message: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

