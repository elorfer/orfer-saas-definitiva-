import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  UseGuards,
  Query,
  ParseIntPipe,
  BadRequestException,
  Header,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';

import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { ArtistsService } from '../artists/artists.service';
import { ArtistSerializer } from '../../common/utils/artist-serializer';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User, UserRole, SubscriptionStatus } from '../../common/entities/user.entity';

@ApiTags('users')
@Controller('users')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly artistsService: ArtistsService,
  ) { }

  @Get()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener todos los usuarios (Solo Admin)' })
  @ApiQuery({ name: 'page', required: false, type: Number, description: 'Número de página' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Elementos por página' })
  @ApiResponse({ status: 200, description: 'Lista de usuarios obtenida exitosamente' })
  async findAll(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
    @Query('search') search?: string,
  ) {
    return this.usersService.findAll(page, limit, search);
  }

  @Get('profile')
  @ApiOperation({ summary: 'Obtener perfil del usuario autenticado' })
  @ApiResponse({ status: 200, description: 'Perfil del usuario' })
  async getProfile(@CurrentUser() user: User) {
    const userData = await this.usersService.findOne(user.id);
    return this.usersService.transformUserData(userData);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener usuario por ID' })
  @ApiResponse({ status: 200, description: 'Usuario encontrado' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async findOne(@Param('id') id: string) {
    const userData = await this.usersService.findOne(id);
    return this.usersService.transformUserData(userData);
  }

  @Patch('profile')
  @ApiOperation({ summary: 'Actualizar perfil del usuario autenticado' })
  @ApiResponse({ status: 200, description: 'Perfil actualizado exitosamente' })
  @ApiResponse({ status: 400, description: 'Datos inválidos' })
  async updateProfile(
    @CurrentUser() user: User,
    @Body() updateUserDto: UpdateUserDto,
  ) {
    return this.usersService.update(user.id, updateUserDto);
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Actualizar usuario (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Usuario actualizado exitosamente' })
  @ApiResponse({ status: 400, description: 'Datos inválidos' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async update(
    @Param('id') id: string,
    @Body() updateUserDto: UpdateUserDto,
  ) {
    return this.usersService.update(id, updateUserDto);
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Eliminar usuario (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Usuario eliminado exitosamente' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async remove(@Param('id') id: string) {
    await this.usersService.remove(id);
    return { message: 'Usuario eliminado exitosamente' };
  }

  @Post(':id/deactivate')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Desactivar usuario (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Usuario desactivado exitosamente' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async deactivate(@Param('id') id: string) {
    return this.usersService.deactivate(id);
  }

  @Post(':id/activate')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Activar usuario (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Usuario activado exitosamente' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async activate(@Param('id') id: string) {
    return this.usersService.activate(id);
  }

  @Post(':id/verify')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Verificar usuario (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Usuario verificado exitosamente' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async verify(@Param('id') id: string) {
    return this.usersService.verify(id);
  }

  @Get('role/:role')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener usuarios por rol (Solo Admin)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de usuarios por rol' })
  async getUsersByRole(
    @Param('role') role: string,
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.usersService.getUsersByRole(role, page, limit);
  }

  @Get('active/list')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener usuarios activos (Solo Admin)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de usuarios activos' })
  async getActiveUsers(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.usersService.getActiveUsers(page, limit);
  }

  @Get('verified/list')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener usuarios verificados (Solo Admin)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de usuarios verificados' })
  async getVerifiedUsers(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.usersService.getVerifiedUsers(page, limit);
  }

  @Get(':userId/followed-artists')
  @ApiOperation({ summary: 'Obtener artistas seguidos por un usuario' })
  @ApiResponse({ status: 200, description: 'Lista de artistas seguidos' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async getFollowedArtists(@Param('userId') userId: string) {
    // Verificar que el usuario existe
    await this.usersService.findOne(userId);

    const artists = await this.artistsService.getFollowedArtists(userId);
    return {
      artists: artists.map((artist) => ArtistSerializer.serializeLite(artist)),
      total: artists.length,
    };
  }

  @Post(':id/premium')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Marcar usuario como premium con plan predefinido o fecha personalizada (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Usuario marcado como premium exitosamente' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async markAsPremium(
    @Param('id') id: string,
    @Body() body: { expiresAt?: string; plan?: 'quincenal' | 'mensual' | 'anual'; amount?: number } = {},
  ) {
    console.log(`[UsersController] markAsPremium solicitado para ${id}`, body);

    // 🔒 VALIDACIÓN: No permitir activar manualmente si tiene RevenueCat activo
    const existingUser = await this.usersService.findOne(id);
    if (existingUser.revenuecatCustomerId && existingUser.subscriptionSource === 'revenuecat') {
      throw new BadRequestException(
        'Este usuario tiene suscripción activa vía RevenueCat. ' +
        'No se puede modificar manualmente. Debe cancelarse desde Google Play o App Store.'
      );
    }

    let expiresAt: Date | undefined;

    // Lógica de planes predefinidos
    if (body?.plan) {
      const now = new Date();
      let baseDate = new Date();

      // Si ya tiene suscripción vigente en el futuro, usarla como base
      if (existingUser.subscriptionExpiresAt && existingUser.subscriptionExpiresAt > now) {
        baseDate = new Date(existingUser.subscriptionExpiresAt);
        console.log(`[UsersController] Acumulando suscripcion desde: ${baseDate.toISOString()}`);
      }

      switch (body.plan) {
        case 'quincenal':
          // setDate retorna timestamp, debemos crear nueva fecha
          expiresAt = new Date(baseDate.setDate(baseDate.getDate() + 15));
          break;
        case 'mensual':
          expiresAt = new Date(baseDate.setMonth(baseDate.getMonth() + 1));
          break;
        case 'anual':
          expiresAt = new Date(baseDate.setFullYear(baseDate.getFullYear() + 1));
          break;
        default:
          console.warn(`[UsersController] Plan no reconocido: ${body.plan}`);
      }
    } else if (body?.expiresAt) {
      // Fecha personalizada
      expiresAt = new Date(body.expiresAt);
    }

    console.log(`[UsersController] Fecha de expiración calculada:`, expiresAt);

    if (expiresAt && isNaN(expiresAt.getTime())) {
      throw new BadRequestException('Fecha de expiración inválida generada');
    }

    const user = await this.usersService.markAsPremium(id, expiresAt, body.amount);
    return this.usersService.transformUserData(user);
  }

  @Get('admin/revenue-stats')
  @ApiOperation({ summary: 'Obtener estadísticas de ingresos manuales' })
  async getManualRevenueStats() {
    return this.usersService.getManualRevenueStats();
  }

  @Get('admin/revenue-stats/monthly')
  @ApiOperation({ summary: 'Obtener desglose mensual de ingresos manuales' })
  async getMonthlyRevenueStats() {
    return this.usersService.getMonthlyRevenueStats();
  }

  @Get('admin/revenue-report/download')
  @ApiOperation({ summary: 'Descargar reporte CSV de pagos manuales' })
  @Header('Content-Type', 'text/csv')
  @Header('Content-Disposition', 'attachment; filename="ingresos_manuales.csv"')
  async downloadRevenueReport() {
    return this.usersService.generateRevenueCsv();
  }

  @Post(':id/sync-revenuecat')
  @ApiOperation({ summary: 'Sincronizar estado premium desde RevenueCat (llamado por la app móvil)' })
  @ApiResponse({ status: 200, description: 'Estado sincronizado exitosamente' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async syncRevenueCatPremium(
    @Param('id') id: string,
    @Body() body: { expiresAt?: string } = {},
  ) {
    console.log(`[UsersController] syncRevenueCatPremium solicitado para ${id}`, body);

    const user = await this.usersService.findOne(id);

    // Actualizar a premium y marcar como RevenueCat
    user.subscriptionStatus = SubscriptionStatus.ACTIVE;
    user.subscriptionSource = 'revenuecat'; // ✅ Marcar como RevenueCat (no manual)

    // Actualizar fecha de expiración si se proporciona
    if (body?.expiresAt) {
      const expiresAt = new Date(body.expiresAt);
      if (!isNaN(expiresAt.getTime())) {
        user.subscriptionExpiresAt = expiresAt;
        user.premiumExpiresAt = expiresAt;
      }
    }

    user.isPremium = true;
    user.lastRevenuecatSync = new Date();

    // ✅ Guardar directamente con el repositorio para que actualice subscription_source
    await this.usersService['userRepository'].save(user);

    console.log(`[UsersController] ✅ Usuario ${id} sincronizado con RevenueCat - source: revenuecat`);

    return {
      success: true,
      message: 'Estado premium sincronizado desde RevenueCat',
      user: this.usersService.transformUserData(user),
    };
  }

  @Post(':id/remove-premium')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Remover premium de usuario (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Premium removido exitosamente' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async removePremium(@Param('id') id: string) {
    // 🔒 VALIDACIÓN: No permitir quitar suscripciones RevenueCat
    const existingUser = await this.usersService.findOne(id);
    if (existingUser.subscriptionSource === 'revenuecat') {
      throw new BadRequestException(
        'No se puede quitar suscripción de RevenueCat. ' +
        'Las suscripciones de Google Play/App Store deben cancelarse desde la tienda.'
      );
    }

    const user = await this.usersService.removePremium(id);
    return this.usersService.transformUserData(user);
  }

  @Get('premium/count')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener número de usuarios premium (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Conteo de usuarios premium' })
  async getPremiumUsersCount() {
    const count = await this.usersService.getPremiumUsersCount();
    return { count };
  }

  // 🔧 ENDPOINT TEMPORAL: Migrar subscription_source (SIN AUTENTICACIÓN)
  @Get('admin/migrate-subscription-source')
  @ApiOperation({ summary: 'Migrar columna subscription_source (TEMPORAL - SIN AUTH)' })
  async migrateSubscriptionSource() {
    try {
      const result = await this.usersService.migrateSubscriptionSource();
      return {
        success: true,
        message: 'Migración completada',
        ...result
      };
    } catch (error) {
      throw new BadRequestException(`Error en migración: ${error.message}`);
    }
  }

  @Get('premium/list')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener lista de usuarios premium (Solo Admin)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de usuarios premium' })
  async getPremiumUsers(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    const result = await this.usersService.getUsersWithActiveSubscription(page, limit);
    return {
      users: result.users.map(user => this.usersService.transformUserData(user)),
      total: result.total,
    };
  }

  @Get('premium/expiring-soon')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener usuarios premium próximos a expirar (Solo Admin)' })
  @ApiQuery({ name: 'days', required: false, type: Number, description: 'Días para considerar próximos a expirar' })
  @ApiResponse({ status: 200, description: 'Lista de usuarios próximos a expirar' })
  async getPremiumUsersExpiringSoon(
    @Query('days', new ParseIntPipe({ optional: true })) days: number = 30,
  ) {
    const users = await this.usersService.getPremiumUsersExpiringSoon(days);
    return {
      users: users.map(user => this.usersService.transformUserData(user)),
      total: users.length,
    };
  }

  @Get('premium/stats')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener estadísticas de usuarios premium (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Estadísticas de premium' })
  async getPremiumStats() {
    return this.usersService.getPremiumStats();
  }
}









