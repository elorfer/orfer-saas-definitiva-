import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AppSetting, SettingKeys } from '../../common/entities/app-setting.entity';

/**
 * Valores por defecto para las configuraciones.
 * Si no existe en la BD, se retorna este valor.
 */
const DEFAULT_VALUES: Record<string, number> = {
  [SettingKeys.AD_FREQUENCY]: 3, // 3 canciones entre cada anuncio
};

@Injectable()
export class SettingsService {
  private readonly logger = new Logger(SettingsService.name);

  constructor(
    @InjectRepository(AppSetting)
    private readonly settingsRepository: Repository<AppSetting>,
  ) {}

  /**
   * Obtiene el valor de una configuración por su llave.
   * Si no existe, retorna el valor por defecto.
   */
  async getValue(key: string): Promise<number> {
    const setting = await this.settingsRepository.findOne({
      where: { key },
    });

    if (setting) {
      return setting.value;
    }

    // Retornar valor por defecto si existe
    return DEFAULT_VALUES[key] ?? 0;
  }

  /**
   * Obtiene la frecuencia de anuncios.
   * @returns Número de canciones entre anuncios
   */
  async getAdFrequency(): Promise<number> {
    return this.getValue(SettingKeys.AD_FREQUENCY);
  }

  /**
   * Actualiza o crea una configuración.
   */
  async setValue(key: string, value: number, description?: string): Promise<AppSetting> {
    let setting = await this.settingsRepository.findOne({
      where: { key },
    });

    if (setting) {
      setting.value = value;
      if (description !== undefined) {
        setting.description = description;
      }
      this.logger.log(`Configuración actualizada: ${key} = ${value}`);
    } else {
      setting = this.settingsRepository.create({
        key,
        value,
        description: description || `Configuración: ${key}`,
      });
      this.logger.log(`Configuración creada: ${key} = ${value}`);
    }

    return this.settingsRepository.save(setting);
  }

  /**
   * Actualiza la frecuencia de anuncios.
   * @param value Número de canciones entre anuncios
   */
  async setAdFrequency(value: number): Promise<AppSetting> {
    return this.setValue(
      SettingKeys.AD_FREQUENCY,
      value,
      'Número de canciones que se reproducen entre cada anuncio',
    );
  }

  /**
   * Obtiene todas las configuraciones.
   */
  async findAll(): Promise<AppSetting[]> {
    return this.settingsRepository.find({
      order: { key: 'ASC' },
    });
  }

  /**
   * Obtiene una configuración por su llave (devuelve la entidad completa).
   */
  async findByKey(key: string): Promise<AppSetting | null> {
    return this.settingsRepository.findOne({
      where: { key },
    });
  }

  /**
   * Elimina una configuración.
   */
  async delete(key: string): Promise<void> {
    const setting = await this.findByKey(key);
    if (!setting) {
      throw new NotFoundException(`Configuración '${key}' no encontrada`);
    }
    await this.settingsRepository.remove(setting);
    this.logger.log(`Configuración eliminada: ${key}`);
  }

  /**
   * Inicializa las configuraciones por defecto si no existen.
   * Útil para ejecutar al iniciar la aplicación.
   */
  async initializeDefaults(): Promise<void> {
    for (const [key, defaultValue] of Object.entries(DEFAULT_VALUES)) {
      const existing = await this.findByKey(key);
      if (!existing) {
        await this.setValue(key, defaultValue);
        this.logger.log(`Configuración por defecto inicializada: ${key} = ${defaultValue}`);
      }
    }
  }
}

