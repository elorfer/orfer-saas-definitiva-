import { Injectable, NotFoundException, BadRequestException, Inject, forwardRef } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';

import { User } from '../../common/entities/user.entity';
import { Artist } from '../../common/entities/artist.entity';
import { SubscriptionStatus } from '../../common/entities/user.entity';
import { UpdateUserDto } from './dto/update-user.dto';
import { RealtimeGateway } from '../realtime/realtime.gateway';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Artist)
    private readonly artistRepository: Repository<Artist>,
    @Inject(forwardRef(() => RealtimeGateway))
    private readonly realtimeGateway: RealtimeGateway,
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
        total_followers: user.artist.totalFollowers,
        total_streams: user.artist.totalStreams,
        monthly_listeners: user.artist.monthlyListeners,
        verification_status: user.artist.verificationStatus,
        created_at: user.artist.createdAt,
        updated_at: user.artist.updatedAt,
      } : null,
    };
  }

  async findAll(page: number = 1, limit: number = 10): Promise<{ users: User[]; total: number }> {
    const [users, total] = await this.userRepository.findAndCount({
      relations: ['artist'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return { users, total };
  }

  async findOne(id: string): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id },
      relations: ['artist'],
    });

    if (!user) {
      throw new NotFoundException('Usuario no encontrado');
    }

    return user;
  }

  async findByEmail(email: string): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { email },
      relations: ['artist'],
    });

    if (!user) {
      throw new NotFoundException('Usuario no encontrado');
    }

    return user;
  }

  async findByUsername(username: string): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { username },
      relations: ['artist'],
    });

    if (!user) {
      throw new NotFoundException('Usuario no encontrado');
    }

    return user;
  }

  async update(id: string, updateUserDto: UpdateUserDto): Promise<User> {
    const user = await this.findOne(id);

    // Verificar si el email ya existe en otro usuario
    if (updateUserDto.email && updateUserDto.email !== user.email) {
      const existingUser = await this.userRepository.findOne({
        where: { email: updateUserDto.email },
      });

      if (existingUser) {
        throw new BadRequestException('El email ya está en uso');
      }
    }

    // Verificar si el username ya existe en otro usuario
    if (updateUserDto.username && updateUserDto.username !== user.username) {
      const existingUser = await this.userRepository.findOne({
        where: { username: updateUserDto.username },
      });

      if (existingUser) {
        throw new BadRequestException('El nombre de usuario ya está en uso');
      }
    }

    Object.assign(user, updateUserDto);
    return this.userRepository.save(user);
  }

  async remove(id: string): Promise<void> {
    const user = await this.findOne(id);
    if (user.artist) {
      await this.artistRepository.delete({ id: user.artist.id });
    }
    await this.userRepository.remove(user);
  }

  async deactivate(id: string): Promise<User> {
    const user = await this.findOne(id);
    user.isActive = false;
    return this.userRepository.save(user);
  }

  async activate(id: string): Promise<User> {
    const user = await this.findOne(id);
    user.isActive = true;
    return this.userRepository.save(user);
  }

  async verify(id: string): Promise<User> {
    const user = await this.findOne(id);
    user.isVerified = true;
    return this.userRepository.save(user);
  }

  async getUsersByRole(role: string, page: number = 1, limit: number = 10): Promise<{ users: User[]; total: number }> {
    const [users, total] = await this.userRepository.findAndCount({
      where: { role: role as any },
      relations: ['artist'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return { users, total };
  }

  async getActiveUsers(page: number = 1, limit: number = 10): Promise<{ users: User[]; total: number }> {
    const [users, total] = await this.userRepository.findAndCount({
      where: { isActive: true },
      relations: ['artist'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return { users, total };
  }

  async getVerifiedUsers(page: number = 1, limit: number = 10): Promise<{ users: User[]; total: number }> {
    const [users, total] = await this.userRepository.findAndCount({
      where: { isVerified: true },
      relations: ['artist'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return { users, total };
  }

  async getUsersWithActiveSubscription(page: number = 1, limit: number = 10): Promise<{ users: User[]; total: number }> {
    const [users, total] = await this.userRepository.findAndCount({
      where: { 
        subscriptionStatus: SubscriptionStatus.ACTIVE,
        subscriptionExpiresAt: MoreThan(new Date()),
      },
      relations: ['artist'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return { users, total };
  }

  async markAsPremium(id: string, expiresAt?: Date): Promise<User> {
    const user = await this.findOne(id);
    const previousStatus = user.subscriptionStatus;
    user.subscriptionStatus = SubscriptionStatus.ACTIVE;
    
    // Si no se proporciona fecha de expiración, establecer 1 año desde ahora
    if (!expiresAt) {
      const oneYearFromNow = new Date();
      oneYearFromNow.setFullYear(oneYearFromNow.getFullYear() + 1);
      user.subscriptionExpiresAt = oneYearFromNow;
    } else {
      user.subscriptionExpiresAt = expiresAt;
    }
    
    const savedUser = await this.userRepository.save(user);
    
    // Notificar cambio de estado premium vía WebSocket
    // Emitir siempre, incluso si ya era ACTIVE (por si el usuario se reconectó)
    try {
      this.realtimeGateway.notifyPremiumStatusChange(user.id, 'active');
    } catch (error) {
      // Log error pero no fallar la operación
      console.error('Error enviando notificación WebSocket:', error);
    }
    
    return savedUser;
  }

  async removePremium(id: string): Promise<User> {
    const user = await this.findOne(id);
    const previousStatus = user.subscriptionStatus;
    user.subscriptionStatus = SubscriptionStatus.INACTIVE;
    user.subscriptionExpiresAt = null;
    
    const savedUser = await this.userRepository.save(user);
    
    // Notificar cambio de estado premium vía WebSocket (si el usuario está conectado)
    if (previousStatus === SubscriptionStatus.ACTIVE) {
      try {
        this.realtimeGateway.notifyPremiumStatusChange(user.id, 'inactive');
      } catch (error) {
        // Silenciar errores de WebSocket
        console.error('Error enviando notificación WebSocket:', error);
      }
    }
    
    return savedUser;
  }

  async getPremiumUsersCount(): Promise<number> {
    return this.userRepository.count({
      where: { 
        subscriptionStatus: SubscriptionStatus.ACTIVE,
        subscriptionExpiresAt: MoreThan(new Date()),
      },
    });
  }

  async getPremiumUsersExpiringSoon(days: number = 30): Promise<User[]> {
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + days);
    
    return this.userRepository.find({
      where: { 
        subscriptionStatus: SubscriptionStatus.ACTIVE,
        subscriptionExpiresAt: MoreThan(new Date()),
      },
      relations: ['artist'],
      order: { subscriptionExpiresAt: 'ASC' },
    }).then(users => 
      users.filter(user => 
        user.subscriptionExpiresAt && 
        user.subscriptionExpiresAt <= futureDate &&
        user.subscriptionExpiresAt > new Date()
      )
    );
  }

  async getPremiumStats(): Promise<{
    total: number;
    expiringSoon: number;
    recentlyAdded: number;
  }> {
    const total = await this.getPremiumUsersCount();
    const expiringSoon = (await this.getPremiumUsersExpiringSoon(30)).length;
    
    // Usuarios premium agregados en los últimos 30 días
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const recentlyAdded = await this.userRepository.count({
      where: { 
        subscriptionStatus: SubscriptionStatus.ACTIVE,
        subscriptionExpiresAt: MoreThan(new Date()),
        updatedAt: MoreThan(thirtyDaysAgo),
      },
    });

    return { total, expiringSoon, recentlyAdded };
  }
}
