import { Module, OnModuleInit } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppSetting } from '../../common/entities/app-setting.entity';
import { SettingsService } from './settings.service';
import { SettingsController } from './settings.controller';
import { PublicSettingsController } from './public-settings.controller';

@Module({
  imports: [TypeOrmModule.forFeature([AppSetting])],
  controllers: [SettingsController, PublicSettingsController],
  providers: [SettingsService],
  exports: [SettingsService],
})
export class SettingsModule implements OnModuleInit {
  constructor(private readonly settingsService: SettingsService) {}

  /**
   * Al iniciar el módulo, inicializa las configuraciones por defecto
   * si no existen en la base de datos.
   */
  async onModuleInit() {
    await this.settingsService.initializeDefaults();
  }
}

