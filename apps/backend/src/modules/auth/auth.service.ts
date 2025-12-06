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

import { User, UserRole } from '../../common/entities/user.entity';
import { Artist } from '../../common/entities/artist.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { JwtPayload } from './interfaces/jwt-payload.interface';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  // Almacenamiento temporal de tokens de recuperación (en producción usar Redis o DB)
  private readonly passwordResetTokens = new Map<string, { userId: string; expiresAt: Date }>();

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Artist)
    private readonly artistRepository: Repository<Artist>,
    private readonly jwtService: JwtService,
  ) {}

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

    // Crear usuario - siempre como USER (no se permite registro como artista o admin)
    const user = this.userRepository.create({
      email: registerDto.email,
      username: registerDto.username,
      passwordHash,
      firstName: registerDto.firstName,
      lastName: registerDto.lastName,
      role: UserRole.USER, // Siempre usuario, sin importar lo que venga en el DTO
    });

    const savedUser = await this.userRepository.save(user);

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

    // Generar token de recuperación
    const resetToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 1); // Token válido por 1 hora

    // Almacenar token temporalmente
    this.passwordResetTokens.set(resetToken, {
      userId: user.id,
      expiresAt,
    });

    // Limpiar tokens expirados periódicamente
    this.cleanExpiredTokens();

    // En producción, aquí enviarías un email con el token
    // Por ahora, devolvemos el token en la respuesta (solo para desarrollo)
    // En producción, esto NO debería devolverse
    if (process.env.NODE_ENV === 'development') {
      console.log(`[DEV] Token de recuperación para ${email}: ${resetToken}`);
      return {
        message: 'Si el email existe, recibirás un enlace para recuperar tu contraseña',
        token: resetToken, // Solo en desarrollo
      };
    }

    return {
      message: 'Si el email existe, recibirás un enlace para recuperar tu contraseña',
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

  private cleanExpiredTokens(): void {
    const now = new Date();
    for (const [token, data] of this.passwordResetTokens.entries()) {
      if (now > data.expiresAt) {
        this.passwordResetTokens.delete(token);
      }
    }
  }
}
