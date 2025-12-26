import {
  Controller,
  Get,
  Put,
  Body,
  Param,
  UseGuards,
  Delete,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
} from '@nestjs/swagger';
import { SettingsService } from './settings.service';
import { UpdateAdFrequencyDto, UpdateSettingDto } from './dto/update-setting.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../../common/entities/user.entity';

@ApiTags('settings')
@Controller('settings')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get()
  @ApiOperation({ summary: 'Obtener todas las configuraciones' })
  @ApiResponse({ status: 200, description: 'Lista de configuraciones obtenida exitosamente' })
  async findAll() {
    return this.settingsService.findAll();
  }

  @Get('ad-frequency')
  @ApiOperation({ summary: 'Obtener la frecuencia de anuncios actual' })
  @ApiResponse({ 
    status: 200, 
    description: 'Frecuencia obtenida exitosamente',
    schema: {
      type: 'object',
      properties: {
        frequency: { type: 'number', example: 3 },
      },
    },
  })
  async getAdFrequency() {
    const frequency = await this.settingsService.getAdFrequency();
    return { frequency };
  }

  @Put('ad-frequency')
  @ApiOperation({ 
    summary: 'Actualizar la frecuencia de anuncios',
    description: 'Cambia el número de canciones que se reproducen entre cada anuncio. Mínimo 1, máximo 20.',
  })
  @ApiResponse({ status: 200, description: 'Frecuencia actualizada exitosamente' })
  @ApiResponse({ status: 400, description: 'Valor inválido' })
  async updateAdFrequency(@Body() dto: UpdateAdFrequencyDto) {
    const setting = await this.settingsService.setAdFrequency(dto.value);
    return {
      message: 'Frecuencia de anuncios actualizada exitosamente',
      setting: {
        key: setting.key,
        value: setting.value,
        updatedAt: setting.updatedAt,
      },
    };
  }

  @Get(':key')
  @ApiOperation({ summary: 'Obtener una configuración por su llave' })
  @ApiParam({ name: 'key', description: 'Llave de la configuración' })
  @ApiResponse({ status: 200, description: 'Configuración obtenida exitosamente' })
  @ApiResponse({ status: 404, description: 'Configuración no encontrada' })
  async findByKey(@Param('key') key: string) {
    const value = await this.settingsService.getValue(key);
    const setting = await this.settingsService.findByKey(key);
    
    return {
      key,
      value,
      description: setting?.description || null,
      updatedAt: setting?.updatedAt || null,
    };
  }

  @Put(':key')
  @ApiOperation({ summary: 'Actualizar o crear una configuración' })
  @ApiParam({ name: 'key', description: 'Llave de la configuración' })
  @ApiResponse({ status: 200, description: 'Configuración actualizada exitosamente' })
  async updateByKey(
    @Param('key') key: string,
    @Body() dto: UpdateSettingDto,
  ) {
    const setting = await this.settingsService.setValue(key, dto.value, dto.description);
    return {
      message: 'Configuración actualizada exitosamente',
      setting: {
        key: setting.key,
        value: setting.value,
        description: setting.description,
        updatedAt: setting.updatedAt,
      },
    };
  }

  @Delete(':key')
  @ApiOperation({ summary: 'Eliminar una configuración' })
  @ApiParam({ name: 'key', description: 'Llave de la configuración' })
  @ApiResponse({ status: 200, description: 'Configuración eliminada exitosamente' })
  @ApiResponse({ status: 404, description: 'Configuración no encontrada' })
  async deleteByKey(@Param('key') key: string) {
    await this.settingsService.delete(key);
    return { message: 'Configuración eliminada exitosamente' };
  }
}











