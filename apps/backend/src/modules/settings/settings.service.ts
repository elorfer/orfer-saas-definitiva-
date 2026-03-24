import { Injectable, Logger, NotFoundException, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AppSetting, SettingKeys } from '../../common/entities/app-setting.entity';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Valores por defecto para las configuraciones.
 * Si no existe en la BD, se retorna este valor.
 */
const DEFAULT_VALUES: Record<string, number | string> = {
  // 📢 ANUNCIOS
  [SettingKeys.AD_FREQUENCY]: 3, // 3 canciones entre cada anuncio

  // 🎵 ALGORITMO DE RECOMENDACIONES
  [SettingKeys.ALGORITHM_HISTORY_SIZE]: 100,       // Historial de exclusión
  [SettingKeys.ALGORITHM_PHASE2_COUNT]: 6,         // Canciones que solicita FASE 2.0
  [SettingKeys.ALGORITHM_PHASE31_COUNT]: 20,       // Canciones que solicita FASE 3.1
  [SettingKeys.ALGORITHM_BUFFER_SIZE]: 5,          // Buffer inicial FASE 1
  [SettingKeys.ALGORITHM_PRELOAD_THRESHOLD]: 3,    // Umbral para disparar precarga
  [SettingKeys.ALGORITHM_CRITICAL_SONGS]: 5,       // Canciones críticas a agregar

  // 🎯 PESOS DEL SCORING (valores 0-100, suman 100)
  [SettingKeys.WEIGHT_GENRE]: 30,       // 30% - Similitud de género
  [SettingKeys.WEIGHT_POPULARITY]: 20,  // 20% - Popularidad relativa
  [SettingKeys.WEIGHT_ARTIST]: 10,      // 10% - Mismo artista
  [SettingKeys.WEIGHT_NOVELTY]: 20,     // 20% - Novedad (canciones recientes)
  [SettingKeys.WEIGHT_AFFINITY]: 20,    // 20% - Afinidad de usuario

  // 📊 CATÁLOGO
  [SettingKeys.CATALOG_SIZE]: 0,                   // Se auto-calcula
  [SettingKeys.CATALOG_SMALL_THRESHOLD]: 150,      // Umbral para "catálogo pequeño"

  // ⚡ RENDIMIENTO Y UX
  'control_debounce_ms': 100,          // Debounce del botón siguiente (ms)
  'preload_cooldown_ms': 500,          // Cooldown entre precargas (ms)
  'min_queue_size': 8,                 // Objetivo de canciones en cola
  'cyclic_buffer_threshold': 5,        // Canciones mínimas antes de permitir repeticiones

  // 🆙 CONTROL DE VERSIONES
  'min_required_build': 8,             // Build mínima obligatoria
  'latest_build': 8,                   // Última build recomendada
  'store_url': 'https://play.google.com/store/apps/details?id=com.struky.app', // URL por defecto
};

import { RealtimeGateway } from '../realtime/realtime.gateway'; // Added import

@Injectable()
export class SettingsService implements OnModuleInit { // Added implements OnModuleInit
  private readonly logger = new Logger(SettingsService.name);

  constructor(
    @InjectRepository(AppSetting)
    private readonly settingsRepository: Repository<AppSetting>,
    private readonly realtimeGateway: RealtimeGateway, // Added RealtimeGateway injection
  ) { }

  /**
   * Obtiene el valor de una configuración.
   */
  async getValue(key: string): Promise<number | string> {
    const setting = await this.findByKey(key);
    if (!setting) {
      return DEFAULT_VALUES[key] ?? 0;
    }
    return setting.textValue ?? setting.value;
  }

  /**
   * Obtiene la frecuencia de anuncios.
   * @returns Número de canciones entre anuncios
   */
  async getAdFrequency(): Promise<number> {
    return this.getValue(SettingKeys.AD_FREQUENCY) as Promise<number>;
  }

  /**
   * Actualiza o crea una configuración.
   */
  async setValue(key: string, value: number | string, description?: string): Promise<AppSetting> {
    let setting = await this.settingsRepository.findOne({
      where: { key },
    });

    if (setting) {
      if (typeof value === 'number') {
        setting.value = value;
        setting.textValue = null;
      } else {
        setting.textValue = value;
        setting.value = null;
      }
      if (description !== undefined) {
        setting.description = description;
      }
      this.logger.log(`Configuración actualizada: ${key} = ${value}`);
    } else {
      setting = this.settingsRepository.create({
        key,
        value: typeof value === 'number' ? value : null,
        textValue: typeof value === 'string' ? value : null,
        description: description || `Configuración: ${key}`,
      });
      this.logger.log(`Configuración creada: ${key} = ${value}`);
    }

    return this.settingsRepository.save(setting);
  }

  /**
   * 🆙 Dispara el evento de prueba de actualización vía WebSockets
   */
  async triggerUpdateTest(): Promise<void> {
    this.logger.log('🚀 Disparando trigger de prueba de actualización');
    this.realtimeGateway.broadcastUpdateTest();
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
  async onModuleInit() {
    // Auto-parche para agregar la columna textValue en producción (si no existe)
    try {
      await this.settingsRepository.query('ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS "textValue" text');
      await this.settingsRepository.query('ALTER TABLE app_settings ALTER COLUMN "value" DROP NOT NULL');
      this.logger.log('✅ Verificación de estructura app_settings completada');
    } catch (e) {
      this.logger.warn('⚠️ No se pudo verificar la estructura de app_settings (ignorar si es sqlite o entorno de pruebas)', e.message);
    }

    await this.initializeDefaults();
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

  /**
   * Lee la versión y build del archivo pubspec.yaml del frontend.
   */
  async getCodeVersion(): Promise<{ version: string; build: number }> {
    try {
      // Ajustar la ruta según la estructura del monorepo
      // Estamos en: apps/backend/src/modules/settings/settings.service.ts
      // Necesitamos: apps/frontend/pubspec.yaml
      const pubspecPath = path.resolve(process.cwd(), 'apps/frontend/pubspec.yaml');
      
      if (!fs.existsSync(pubspecPath)) {
        this.logger.warn(`No se encontró pubspec.yaml en: ${pubspecPath}`);
        return { version: '0.0.0', build: 0 };
      }

      const content = fs.readFileSync(pubspecPath, 'utf8');
      const versionMatch = content.match(/^version:\s*([^\s]+)/m);
      
      if (versionMatch && versionMatch[1]) {
        const fullVersion = versionMatch[1]; // ej: 1.0.1+8
        const [version, buildStr] = fullVersion.split('+');
        return {
          version: version,
          build: parseInt(buildStr) || 0
        };
      }

      return { version: '0.0.0', build: 0 };
    } catch (error) {
      this.logger.error('Error al leer pubspec.yaml', error);
      return { version: '0.0.0', build: 0 };
    }
  }
}
