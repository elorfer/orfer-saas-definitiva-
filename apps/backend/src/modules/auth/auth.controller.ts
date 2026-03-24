import {
  Controller,
  Post,
  Body,
  UseGuards,
  Request,
  Get,
  Put,
  Param,
  HttpCode,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';

import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { SocialLoginDto } from './dto/social-login.dto'; // 🔐 Social Login
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  private readonly logger = new Logger(AuthController.name);

  constructor(private readonly authService: AuthService) { }

  @Post('register')
  @ApiOperation({ summary: 'Registrar nuevo usuario' })
  @ApiResponse({ status: 201, description: 'Usuario registrado exitosamente' })
  @ApiResponse({ status: 409, description: 'Email o username ya existe' })
  async register(@Body() registerDto: RegisterDto) {
    return this.authService.register(registerDto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Iniciar sesión' })
  @ApiResponse({ status: 200, description: 'Login exitoso' })
  @ApiResponse({ status: 401, description: 'Credenciales inválidas' })
  async login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @Post('social/login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '🔐 Login con Google/Facebook OAuth' })
  @ApiResponse({ status: 200, description: 'Login social exitoso' })
  @ApiResponse({ status: 401, description: 'Token OAuth inválido' })
  async socialLogin(@Body() socialLoginDto: SocialLoginDto) {
    return this.authService.socialLogin(socialLoginDto);
  }

  @Post('refresh')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Renovar token de acceso' })
  @ApiResponse({ status: 200, description: 'Token renovado exitosamente' })
  async refreshToken(@Request() req) {
    return this.authService.refreshToken(req.user);
  }

  @Get('profile')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Obtener perfil del usuario autenticado' })
  @ApiResponse({ status: 200, description: 'Perfil del usuario' })
  async getProfile(@Request() req) {
    return {
      user: this.authService.transformUserData(req.user),
    };
  }

  @Put('change-password')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Cambiar contraseña' })
  @ApiResponse({ status: 200, description: 'Contraseña cambiada exitosamente' })
  @ApiResponse({ status: 400, description: 'Contraseña actual incorrecta' })
  async changePassword(@Request() req, @Body() changePasswordDto: ChangePasswordDto) {
    return this.authService.changePassword(
      req.user.id,
      changePasswordDto.oldPassword,
      changePasswordDto.newPassword,
    );
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Cerrar sesión' })
  @ApiResponse({ status: 200, description: 'Sesión cerrada exitosamente' })
  async logout() {
    // En una implementación más avanzada, podrías invalidar el token
    return { message: 'Sesión cerrada exitosamente' };
  }

  @Get('check-username/:username')
  @ApiOperation({ summary: 'Verificar disponibilidad de nombre de usuario' })
  @ApiResponse({ status: 200, description: 'Disponibilidad del username' })
  async checkUsername(@Param('username') username: string) {
    // Decodificar el username que viene en la URL
    const decodedUsername = decodeURIComponent(username);
    this.logger.log(`[checkUsername] Petición recibida - Username recibido: "${username}", Decodificado: "${decodedUsername}"`);
    const result = await this.authService.checkUsernameAvailability(decodedUsername);
    this.logger.log(`[checkUsername] Resultado: ${JSON.stringify(result)}`);
    return result;
  }

  @Get('check-email/:email')
  @ApiOperation({ summary: 'Verificar disponibilidad de email' })
  @ApiResponse({ status: 200, description: 'Disponibilidad del email' })
  async checkEmail(@Param('email') email: string) {
    // Decodificar el email que viene en la URL
    const decodedEmail = decodeURIComponent(email);
    this.logger.log(`[checkEmail] Petición recibida - Email recibido: "${email}", Decodificado: "${decodedEmail}"`);
    const result = await this.authService.checkEmailAvailability(decodedEmail);
    this.logger.log(`[checkEmail] Resultado: ${JSON.stringify(result)}`);
    return result;
  }

  @Post('forgot-password')
  @ApiOperation({ summary: 'Solicitar recuperación de contraseña' })
  @ApiResponse({ status: 200, description: 'Email de recuperación enviado' })
  @ApiResponse({ status: 400, description: 'Email inválido' })
  async forgotPassword(@Body() forgotPasswordDto: ForgotPasswordDto) {
    return this.authService.forgotPassword(forgotPasswordDto.email);
  }

  @Post('reset-password')
  @ApiOperation({ summary: 'Restablecer contraseña con token' })
  @ApiResponse({ status: 200, description: 'Contraseña restablecida exitosamente' })
  @ApiResponse({ status: 400, description: 'Token inválido o expirado' })
  async resetPassword(@Body() resetPasswordDto: ResetPasswordDto) {
    return this.authService.resetPassword(resetPasswordDto.token, resetPasswordDto.newPassword);
  }

  @Post('verify-email-code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verificar email con código de 6 dígitos (OTP)' })
  @ApiResponse({ status: 200, description: 'Email verificado exitosamente' })
  @ApiResponse({ status: 400, description: 'Código incorrecto o expirado' })
  async verifyEmailByCode(@Body() body: { email: string; code: string }) {
    return this.authService.verifyEmailByCode(body.email, body.code);
  }

  @Get('reset-admin-demo')
  @ApiOperation({ summary: 'TEMPORAL: Resetear admin en produccion' })
  async resetAdminDemo() {
    return this.authService.resetAdminProduction();
  }
}









