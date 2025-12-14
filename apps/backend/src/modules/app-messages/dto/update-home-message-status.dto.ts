import { IsBoolean } from 'class-validator';

export class UpdateHomeMessageStatusDto {
  @IsBoolean()
  isActive: boolean;
}





