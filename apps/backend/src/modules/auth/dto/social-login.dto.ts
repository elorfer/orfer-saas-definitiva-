import { IsString, IsEmail, IsOptional, IsIn } from 'class-validator';

export class SocialLoginDto {
    @IsString()
    @IsIn(['google', 'facebook'])
    provider: 'google' | 'facebook';

    @IsString()
    accessToken: string;

    @IsEmail()
    email: string;

    @IsString()
    displayName: string;

    @IsOptional()
    @IsString()
    photoUrl?: string;
}
