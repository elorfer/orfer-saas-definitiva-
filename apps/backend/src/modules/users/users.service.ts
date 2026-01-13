import { Injectable, NotFoundException, BadRequestException, Inject, forwardRef } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan, ILike } from 'typeorm';

import { User } from '../../common/entities/user.entity';
import { Artist } from '../../common/entities/artist.entity';
import { SubscriptionStatus } from '../../common/entities/user.entity';
import { UpdateUserDto } from './dto/update-user.dto';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { Payment, PaymentMethod, PaymentStatus } from '../../common/entities/payment.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Artist)
    private readonly artistRepository: Repository<Artist>,
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    @Inject(forwardRef(() => RealtimeGateway))
    private readonly realtimeGateway: RealtimeGateway,
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
      subscription_source: user.subscriptionSource, // ✅ Incluir fuente de suscripción
      subscription_expires_at: user.subscriptionExpiresAt,
      revenuecat_customer_id: user.revenuecatCustomerId,
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
        total_followers: user.artist.totalFollowers,
        total_streams: user.artist.totalStreams,
        monthly_listeners: user.artist.monthlyListeners,
        verification_status: user.artist.verificationStatus,
        created_at: user.artist.createdAt,
        updated_at: user.artist.updatedAt,
      } : null,
    };
  }

  async findAll(page: number = 1, limit: number = 10, search?: string): Promise<{ users: User[]; total: number }> {
    const whereCondition: any = [];

    if (search) {
      whereCondition.push({ email: ILike(`%${search}%`) });
      whereCondition.push({ username: ILike(`%${search}%`) });
      whereCondition.push({ firstName: ILike(`%${search}%`) });
      whereCondition.push({ lastName: ILike(`%${search}%`) });
    }

    const [users, total] = await this.userRepository.findAndCount({
      where: search ? whereCondition : undefined,
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
        // Eliminado filtro de fecha para incluir lifetime y revenuecat (que gestionan status)
      },
      relations: ['artist'],
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return { users, total };
  }

  async markAsPremium(id: string, expiresAt?: Date, amount?: number): Promise<User> {
    const user = await this.findOne(id);
    const previousStatus = user.subscriptionStatus;
    user.subscriptionStatus = SubscriptionStatus.ACTIVE;
    user.subscriptionSource = 'manual'; // ✅ Marcar como activación manual

    // Si no se proporciona fecha de expiración, establecer 1 año desde ahora
    if (!expiresAt) {
      const oneYearFromNow = new Date();
      oneYearFromNow.setFullYear(oneYearFromNow.getFullYear() + 1);
      user.subscriptionExpiresAt = oneYearFromNow;
    } else {
      user.subscriptionExpiresAt = expiresAt;
    }

    const savedUser = await this.userRepository.save(user);

    // 💰 Registrar pago manual si se proporciona monto
    if (amount && amount > 0) {
      try {
        const payment = this.paymentRepository.create({
          user: savedUser,
          amount: amount,
          currency: 'USD',
          paymentMethod: PaymentMethod.MANUAL,
          status: PaymentStatus.COMPLETED,
          subscriptionPeriodStart: new Date(), // Fecha actual como inicio
          subscriptionPeriodEnd: savedUser.subscriptionExpiresAt,
        });

        await this.paymentRepository.save(payment);
        console.log(`[UsersService] Pago manual registrado: $${amount} para usuario ${savedUser.email}`);
      } catch (error) {
        console.error('Error registrando pago manual:', error);
        // No fallamos la transacción principal, pero lo logueamos
      }
    }

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

  // 🔧 MÉTODO TEMPORAL: Migrar subscription_source
  async migrateSubscriptionSource(): Promise<{
    columnCreated: boolean;
    usersUpdated: number;
    revenuecatUsers: number;
    manualUsers: number;
  }> {
    try {
      // 1. Crear columna si no existe
      await this.userRepository.query(`
        ALTER TABLE users 
        ADD COLUMN IF NOT EXISTS subscription_source VARCHAR(20) DEFAULT 'manual'
      `);

      // 2. Actualizar usuarios con RevenueCat
      const updateResult = await this.userRepository.query(`
        UPDATE users 
        SET subscription_source = 'revenuecat' 
        WHERE revenuecat_customer_id IS NOT NULL
      `);

      // 3. Obtener estadísticas
      const stats = await this.userRepository.query(`
        SELECT 
          COUNT(*) FILTER (WHERE subscription_source = 'revenuecat') as revenuecat_count,
          COUNT(*) FILTER (WHERE subscription_source = 'manual') as manual_count
        FROM users
      `);

      return {
        columnCreated: true,
        usersUpdated: updateResult[1] || 0,
        revenuecatUsers: parseInt(stats[0]?.revenuecat_count || '0'),
        manualUsers: parseInt(stats[0]?.manual_count || '0'),
      };
    } catch (error) {
      console.error('Error en migración:', error);
      throw error;
    }
  }

  /**
   * Obtener estadísticas de ingresos manuales
   */
  async getManualRevenueStats() {
    const result = await this.paymentRepository
      .createQueryBuilder('payment')
      .select('SUM(payment.amount)', 'total')
      .where('payment.paymentMethod = :method', { method: PaymentMethod.MANUAL })
      .getRawOne();

    return {
      totalManualRevenue: parseFloat(result?.total || '0'),
    };
  }

  /**
   * Obtener ingresos manuales agrupados por mes (últimos 12 meses)
   */
  async getMonthlyRevenueStats() {
    const result = await this.paymentRepository.query(`
      SELECT 
        to_char(created_at, 'YYYY-MM') as month,
        SUM(amount) as total,
        COUNT(*) as count
      FROM payments
      WHERE payment_method = 'manual'
      GROUP BY 1
      ORDER BY 1 DESC
      LIMIT 12
    `);

    return result.map(row => ({
      month: row.month,
      total: parseFloat(row.total),
      count: parseInt(row.count)
    }));
  }

  /**
   * Generar CSV de pagos manuales
   */
  async generateRevenueCsv(): Promise<string> {
    const payments = await this.paymentRepository.find({
      where: { paymentMethod: PaymentMethod.MANUAL },
      relations: ['user'],
      order: { createdAt: 'DESC' }
    });

    const header = 'ID Pago,Fecha,Usuario,Email,Monto (USD),Estado\n';
    const rows = payments.map(p => {
      const date = p.createdAt.toISOString().split('T')[0];
      const user = p.user ? `${p.user.firstName} ${p.user.lastName}` : 'Usuario eliminado';
      const email = p.user?.email || 'N/A';
      return `${p.id},${date},"${user}",${email},${p.amount},${p.status}`;
    }).join('\n');

    return header + rows;
  }
}
