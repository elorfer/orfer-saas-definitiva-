import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { RealtimeService } from './realtime.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../../common/entities/user.entity';

@ApiTags('realtime')
@Controller('realtime')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class RealtimeController {
  constructor(private readonly realtimeService: RealtimeService) {}

  @Get('active-users-count')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener conteo de usuarios realmente activos (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Conteo de usuarios activos' })
  async getActiveUsersCount() {
    const count = await this.realtimeService.getRealActiveUsersCount();
    return { count, timestamp: new Date().toISOString() };
  }

  @Get('active-users')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener lista de usuarios realmente activos (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Lista de usuarios activos' })
  async getActiveUsers() {
    const users = await this.realtimeService.getRealActiveUsers(50);
    return { users, count: users.length, timestamp: new Date().toISOString() };
  }

  @Get('stats')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Obtener estadísticas combinadas (Solo Admin)' })
  @ApiResponse({ status: 200, description: 'Estadísticas combinadas' })
  async getStats() {
    return this.realtimeService.getCombinedStats();
  }
}













