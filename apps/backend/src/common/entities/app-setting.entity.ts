import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

/**
 * Entidad para almacenar configuraciones globales de la aplicación.
 * Usa un sistema key-value para flexibilidad.
 */
@Entity('app_settings')
export class AppSetting {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 100, unique: true })
  @Index('idx_app_settings_key')
  key: string;

  @Column({ type: 'int' })
  value: number;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}

/**
 * Constantes para las llaves de configuración conocidas.
 * Esto ayuda a evitar errores de tipeo y facilita el autocompletado.
 */
export const SettingKeys = {
  AD_FREQUENCY: 'ad_frequency', // Número de canciones entre anuncios
} as const;

export type SettingKey = typeof SettingKeys[keyof typeof SettingKeys];


