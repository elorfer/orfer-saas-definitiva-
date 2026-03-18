import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  BadRequestException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import * as crypto from 'crypto';
import { google } from 'googleapis'; // 🔵 Google OAuth
import axios from 'axios'; // 🌐 HTTP client

import { User, UserRole } from '../../common/entities/user.entity';
import { Artist } from '../../common/entities/artist.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { SocialLoginDto } from './dto/social-login.dto'; // 🔐 Social Login
import { JwtPayload } from './interfaces/jwt-payload.interface';
import { ResendService } from '../../common/services/resend.service';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  // Almacenamiento temporal de tokens de recuperación (en producción usar Redis o DB)
  private readonly passwordResetTokens = new Map<string, { userId: string; expiresAt: Date }>();
  // Almacenamiento temporal de tokens de verificación de email
  private readonly emailVerificationTokens = new Map<string, { userId: string; email: string; expiresAt: Date }>();

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Artist)
    private readonly artistRepository: Repository<Artist>,
    private readonly jwtService: JwtService,
    private readonly resendService: ResendService,
  ) { }

  /**
   * Transforma los datos de usuario de camelCase a snake_case para la API
   */
  public transformUserData(user: User): any {
    return {
      id: user.id,
      email: user.email,
      username: user.username,
      first_name: user.firstName,
      last_name: user.lastName,
      avatar_url: user.avatarUrl,
      role: user.role,
      subscription_status: user.subscriptionStatus,
      subscription_source: user.subscriptionSource, // ✅ Incluir fuente
      is_premium: user.isPremium,
      premium_expires_at: user.premiumExpiresAt,
      is_verified: user.isVerified,
      is_active: user.isActive,
      last_login_at: user.lastLoginAt,
      created_at: user.createdAt,
      updated_at: user.updatedAt,
      artist: user.artist ? {
        id: user.artist.id,
        user_id: user.artist.userId,
        stage_name: user.artist.stageName,
        bio: user.artist.bio,
        website_url: user.artist.websiteUrl,
        social_links: user.artist.socialLinks,
        verification_status: user.artist.verificationStatus,
        total_streams: user.artist.totalStreams,
        total_followers: user.artist.totalFollowers,
        monthly_listeners: user.artist.monthlyListeners,
        created_at: user.artist.createdAt,
        updated_at: user.artist.updatedAt,
      } : null,
    };
  }

  async validateUser(email: string, password: string): Promise<any> {
    const user = await this.userRepository.findOne({
      where: { email },
      relations: ['artist'],
    });

    if (user && (await bcrypt.compare(password, user.passwordHash))) {
      const { passwordHash, ...result } = user;
      return result;
    }
    return null;
  }

  async login(loginDto: LoginDto) {
    const user = await this.validateUser(loginDto.email, loginDto.password);

    if (!user) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    if (!user.isActive) {
      throw new UnauthorizedException('Cuenta desactivada');
    }

    if (!user.isVerified) {
      throw new UnauthorizedException('Debes verificar tu email antes de iniciar sesión. Revisa tu bandeja de entrada.');
    }

    // Actualizar último login
    await this.userRepository.update(user.id, {
      lastLoginAt: new Date(),
    });

    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      username: user.username,
      role: user.role,
    };

    return {
      access_token: this.jwtService.sign(payload),
      user: this.transformUserData(user),
    };
  }

  async register(registerDto: RegisterDto) {
    // Verificar si el email ya existe
    const existingUserByEmail = await this.userRepository.findOne({
      where: { email: registerDto.email },
    });

    if (existingUserByEmail) {
      throw new ConflictException('El email ya está registrado');
    }

    // Verificar si el username ya existe
    const existingUserByUsername = await this.userRepository.findOne({
      where: { username: registerDto.username },
    });

    if (existingUserByUsername) {
      throw new ConflictException('El nombre de usuario ya está en uso');
    }

    // Hash de la contraseña
    const saltRounds = 12;
    const passwordHash = await bcrypt.hash(registerDto.password, saltRounds);

    // Crear usuario
    // Si viene un rol en el DTO, usarlo (para creación desde admin panel)
    // Si no viene, crear como USER por defecto (registro público)
    const user = this.userRepository.create({
      email: registerDto.email,
      username: registerDto.username,
      passwordHash,
      firstName: registerDto.firstName,
      lastName: registerDto.lastName,
      role: registerDto.role || UserRole.USER, // Usar rol del DTO si existe, sino USER por defecto
    });

    const savedUser = await this.userRepository.save(user);

    // 🔥 SINCRONIZAR CON FIREBASE AUTH (para forgot password)
    try {
      const admin = (await import('firebase-admin')).default;

      if (admin.apps.length > 0) {
        // Crear usuario en Firebase Auth
        await admin.auth().createUser({
          email: registerDto.email,
          password: registerDto.password, // Firebase hashea automáticamente
          displayName: `${registerDto.firstName} ${registerDto.lastName}`,
          emailVerified: false, // Se puede verificar después
        });

        this.logger.log(`✅ Usuario sincronizado con Firebase Auth: ${registerDto.email}`);
      }
    } catch (firebaseError) {
      // Si Firebase falla, NO bloquear el registro
      // El usuario puede registrarse igual, pero forgot password no funcionará hasta sincronizar
      if (firebaseError.code === 'auth/email-already-exists') {
        this.logger.warn(`⚠️ Usuario ya existe en Firebase Auth: ${registerDto.email}`);
      } else {
        this.logger.error(`❌ Error creando usuario en Firebase Auth:`, firebaseError.message);
      }
    }

    // 📧 ENVIAR CÓDIGO DE VERIFICACIÓN (OTP) CON RESEND
    try {
      // Generar código de 6 dígitos
      const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = new Date();
      expiresAt.setHours(expiresAt.getHours() + 24); // Válido por 24 horas

      // Guardar en el usuario
      await this.userRepository.update(savedUser.id, {
        verificationCode,
        verificationCodeExpiresAt: expiresAt,
      });

      await this.resendService.sendWelcomeVerificationEmail(savedUser.email, verificationCode);
      this.logger.log(`📧 Código OTP enviado para: ${savedUser.email}`);
    } catch (emailError) {
      this.logger.error(`❌ Error al enviar código OTP:`, emailError);
    }

    // No se crea perfil de artista - solo se permite registro como usuario

    const payload: JwtPayload = {
      sub: savedUser.id,
      email: savedUser.email,
      username: savedUser.username,
      role: savedUser.role,
    };

    return {
      access_token: this.jwtService.sign(payload),
      user: this.transformUserData(savedUser),
    };
  }

  /**
   * 🌐 LOGIN SOCIAL (Google/Facebook)
   * Verifica el token OAuth y crea/loguea el usuario automáticamente
   */
  async socialLogin(socialLoginDto: SocialLoginDto) {
    const { provider, accessToken, email, displayName, photoUrl } = socialLoginDto;

    // TODO: Verificar token según provider
    // Por ahora confiamos en el token del frontend
    // En producción DEBES verificar el token con Google/Facebook APIs

    // Buscar usuario por email
    let user = await this.userRepository.findOne({
      where: { email },
      relations: ['artist'],
    });

    if (!user) {
      // Usuario no existe - crear nuevo
      this.logger.log(`🆕 Creando nuevo usuario desde ${provider}: ${email}`);

      // Generar username único desde email
      const baseUsername = email.split('@')[0].toLowerCase().replace(/[^a-z0-9_]/g, '');
      let username = baseUsername;
      let attempts = 0;

      // Verificar que el username no exista
      while (attempts < 100) {
        const existing = await this.userRepository.findOne({ where: { username } });
        if (!existing) break;

        username = `${baseUsername}${Math.floor(Math.random() * 10000)}`;
        attempts++;
      }

      // Generar password aleatorio (no se usará nunca)
      const randomPassword = crypto.randomBytes(32).toString('hex');
      const passwordHash = await bcrypt.hash(randomPassword, 12);

      // Crear usuario
      user = this.userRepository.create({
        email,
        username,
        passwordHash,
        firstName: displayName.split(' ')[0] || 'Usuario',
        lastName: displayName.split(' ').slice(1).join(' ') || '',
        avatarUrl: photoUrl || null,
        role: UserRole.USER,
        // Email verificado automáticamente (Google/Facebook ya lo verificó)
        isVerified: true,
      });

      user = await this.userRepository.save(user);
      this.logger.log(`✅ Usuario creado exitosamente: ${user.id}`);
    } else {
      // Usuario existe - actualizar último login
      this.logger.log(`🔄 Usuario existente desde ${provider}: ${email}`);
      await this.userRepository.update(user.id, {
        lastLoginAt: new Date(),
        // Actualizar foto si viene y no tiene
        ...(photoUrl && !user.avatarUrl ? { avatarUrl: photoUrl } : {}),
      });
    }

    // Generar JWT
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      username: user.username,
      role: user.role,
    };

    return {
      access_token: this.jwtService.sign(payload),
      user: this.transformUserData(user),
    };
  }

  async refreshToken(user: User) {
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      username: user.username,
      role: user.role,
    };

    return {
      access_token: this.jwtService.sign(payload),
    };
  }

  async changePassword(userId: string, oldPassword: string, newPassword: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
    });

    if (!user) {
      throw new UnauthorizedException('Usuario no encontrado');
    }

    // Verificar contraseña actual
    const isOldPasswordValid = await bcrypt.compare(oldPassword, user.passwordHash);
    if (!isOldPasswordValid) {
      throw new BadRequestException('La contraseña actual es incorrecta');
    }

    // Hash de la nueva contraseña
    const saltRounds = 12;
    const newPasswordHash = await bcrypt.hash(newPassword, saltRounds);

    // Actualizar contraseña
    await this.userRepository.update(userId, {
      passwordHash: newPasswordHash,
    });

    return { message: 'Contraseña actualizada exitosamente' };
  }

  async validateJwtPayload(payload: JwtPayload): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id: payload.sub },
      relations: ['artist'],
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Token inválido o usuario inactivo');
    }

    return user;
  }

  async checkUsernameAvailability(username: string): Promise<{ available: boolean }> {
    try {
      // Limpiar el username
      const cleanUsername = username.trim();

      // Permitir verificación desde 1 carácter (pero el registro requerirá mínimo 3)
      if (!cleanUsername || cleanUsername.length < 1) {
        return { available: false }; // Vacío, no disponible
      }

      // Buscar usuario usando búsqueda exacta (case-sensitive primero, más rápido)
      // Si no encuentra, hacer búsqueda case-insensitive
      let existingUser = await this.userRepository.findOne({
        where: { username: cleanUsername },
      });

      // Si no encontró con búsqueda exacta, buscar case-insensitive
      if (!existingUser) {
        existingUser = await this.userRepository
          .createQueryBuilder('user')
          .where('LOWER(user.username) = LOWER(:username)', { username: cleanUsername })
          .getOne();
      }

      // Si existe un usuario, NO está disponible
      const available = !existingUser;

      this.logger.log(`[checkUsernameAvailability] Username: "${cleanUsername}", Existe: ${!!existingUser}, Disponible: ${available}`);

      return { available };
    } catch (error) {
      // En caso de error, registrar y asumir que NO está disponible para ser más seguro
      this.logger.error(`[checkUsernameAvailability] Error verificando disponibilidad de username: "${username}"`, error);
      return { available: false }; // En caso de error, asumir no disponible para ser más seguro
    }
  }

  async checkEmailAvailability(email: string): Promise<{ available: boolean }> {
    try {
      // Limpiar el email
      const cleanEmail = email.trim().toLowerCase();

      if (!cleanEmail || cleanEmail.length < 1) {
        return { available: false }; // Vacío, no disponible
      }

      // Buscar usuario usando búsqueda exacta (case-sensitive primero, más rápido)
      // Si no encuentra, hacer búsqueda case-insensitive
      let existingUser = await this.userRepository.findOne({
        where: { email: cleanEmail },
      });

      // Si no encontró con búsqueda exacta, buscar case-insensitive
      if (!existingUser) {
        existingUser = await this.userRepository
          .createQueryBuilder('user')
          .where('LOWER(user.email) = LOWER(:email)', { email: cleanEmail })
          .getOne();
      }

      // Si existe un usuario, NO está disponible
      const available = !existingUser;

      this.logger.log(`[checkEmailAvailability] Email: "${cleanEmail}", Existe: ${!!existingUser}, Disponible: ${available}`);

      return { available };
    } catch (error) {
      // En caso de error, registrar y asumir que NO está disponible para ser más seguro
      this.logger.error(`[checkEmailAvailability] Error verificando disponibilidad de email: "${email}"`, error);
      return { available: false }; // En caso de error, asumir no disponible para ser más seguro
    }
  }

  /**
   * 🔐 Solicitar recuperación de contraseña con Resend
   * Genera token, almacena en memoria y envía email profesional
   */
  async forgotPassword(email: string): Promise<{ message: string; token?: string }> {
    const user = await this.userRepository.findOne({
      where: { email },
    });

    // Por seguridad, siempre devolver el mismo mensaje aunque el usuario no exista
    if (!user) {
      return {
        message: 'Si el email existe, recibirás un enlace para recuperar tu contraseña',
      };
    }

    try {
      // Generar token de recuperación
      const resetToken = crypto.randomBytes(32).toString('hex');
      const expiresAt = new Date();
      expiresAt.setHours(expiresAt.getHours() + 1); // Token válido por 1 hora

      // Almacenar token en memoria
      this.passwordResetTokens.set(resetToken, {
        userId: user.id,
        expiresAt,
      });

      // Limpiar tokens expirados
      this.cleanExpiredTokens();

      // Enviar email con Resend
      const emailSent = await this.resendService.sendPasswordResetEmail(email, resetToken);

      if (emailSent) {
        this.logger.log(`✅ Email de recuperación enviado a: ${email}`);
      } else {
        this.logger.warn(`⚠️ No se pudo enviar email a: ${email}`);
      }

      // En desarrollo, devolver token para testing
      if (process.env.NODE_ENV === 'development') {
        this.logger.log(`[DEV] Token de recuperación: ${resetToken}`);
        return {
          message: 'Si el email existe, recibirás un enlace para recuperar tu contraseña',
          token: resetToken, // Solo en desarrollo
        };
      }

      return {
        message: 'Si el email existe, recibirás un enlace para recuperar tu contraseña',
      };
    } catch (error) {
      this.logger.error(`❌ Error en forgot password:`, error);
      return {
        message: 'Si el email existe, recibirás un enlace para recuperar tu contraseña',
      };
    }
  }

  /**
   * Método de fallback para recuperación de contraseña sin Firebase
   */
  private forgotPasswordFallback(email: string, userId: string): { message: string; token: string } {
    // Generar token de recuperación
    const resetToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 1); // Token válido por 1 hora

    // Almacenar token temporalmente
    this.passwordResetTokens.set(resetToken, {
      userId,
      expiresAt,
    });

    // Limpiar tokens expirados periódicamente
    this.cleanExpiredTokens();

    // En desarrollo, devolver token para testing
    if (process.env.NODE_ENV === 'development') {
      console.log(`[DEV] Token de recuperación para ${email}: ${resetToken}`);
      return {
        message: 'Si el email existe, recibirás un enlace para recuperar tu contraseña',
        token: resetToken, // Solo en desarrollo
      };
    }

    return {
      message: 'Si el email existe, recibirás un enlace para recuperar tu contraseña',
      token: undefined,
    };
  }

  async resetPassword(token: string, newPassword: string): Promise<{ message: string }> {
    const tokenData = this.passwordResetTokens.get(token);

    if (!tokenData) {
      throw new BadRequestException('Token de recuperación inválido o expirado');
    }

    if (new Date() > tokenData.expiresAt) {
      this.passwordResetTokens.delete(token);
      throw new BadRequestException('Token de recuperación expirado');
    }

    const user = await this.userRepository.findOne({
      where: { id: tokenData.userId },
    });

    if (!user) {
      this.passwordResetTokens.delete(token);
      throw new NotFoundException('Usuario no encontrado');
    }

    // Hash de la nueva contraseña
    const saltRounds = 12;
    const passwordHash = await bcrypt.hash(newPassword, saltRounds);

    // Actualizar contraseña
    await this.userRepository.update(user.id, {
      passwordHash,
    });

    // Eliminar token usado
    this.passwordResetTokens.delete(token);

    return {
      message: 'Contraseña restablecida exitosamente',
    };
  }

  async verifyEmailByCode(email: string, code: string): Promise<any> {
    const user = await this.userRepository.findOne({
      where: { email },
    });

    if (!user) {
      throw new NotFoundException('Usuario no encontrado');
    }

    if (user.isVerified) {
      const payload: JwtPayload = {
        sub: user.id,
        email: user.email,
        username: user.username,
        role: user.role,
      };
      return {
        access_token: this.jwtService.sign(payload),
        user: this.transformUserData(user),
        message: 'Tu cuenta ya está verificada. ¡Iniciando sesión automáticamente!',
      };
    }

    if (!user.verificationCode || user.verificationCode !== code) {
      throw new BadRequestException('El código ingresado es incorrecto');
    }

    if (user.verificationCodeExpiresAt && new Date() > user.verificationCodeExpiresAt) {
      throw new BadRequestException('El código ha expirado. Por favor, solicita uno nuevo.');
    }

    // Actualizar estado de verificación y limpiar código
    const updatedUser = await this.userRepository.save({
      ...user,
      isVerified: true,
      verificationCode: null,
      verificationCodeExpiresAt: null,
    });

    this.logger.log(`✅ Email verificado exitosamente con OTP para: ${user.email}`);

    // 🔥 LOGIN AUTOMÁTICO: Generar JWT tras verificar
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      username: user.username,
      role: user.role,
    };

    return {
      access_token: this.jwtService.sign(payload),
      user: this.transformUserData(updatedUser),
      message: 'Email verificado exitosamente. ¡Bienvenido a Struky!',
    };
  }

  private cleanExpiredTokens(): void {
    const now = new Date();
    // Limpiar tokens de password reset
    for (const [token, data] of this.passwordResetTokens.entries()) {
      if (now > data.expiresAt) {
        this.passwordResetTokens.delete(token);
      }
    }
    // Limpiar tokens de verificación de email
    for (const [token, data] of this.emailVerificationTokens.entries()) {
      if (now > data.expiresAt) {
        this.emailVerificationTokens.delete(token);
      }
    }
  }
}
