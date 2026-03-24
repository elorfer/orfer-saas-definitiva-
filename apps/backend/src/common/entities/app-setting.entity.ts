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

  @Column({ type: 'int', nullable: true })
  value: number;

  @Column({ type: 'text', nullable: true })
  textValue?: string;

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
  // 📢 ANUNCIOS
  AD_FREQUENCY: 'ad_frequency', // Número de canciones entre anuncios

  // 🎵 ALGORITMO DE RECOMENDACIONES
  ALGORITHM_HISTORY_SIZE: 'algorithm_history_size',         // Historial de exclusión (default: 100)
  ALGORITHM_PHASE2_COUNT: 'algorithm_phase2_count',         // Canciones que solicita FASE 2.0 (default: 6)
  ALGORITHM_PHASE31_COUNT: 'algorithm_phase31_count',       // Canciones que solicita FASE 3.1 (default: 20)
  ALGORITHM_BUFFER_SIZE: 'algorithm_buffer_size',           // Buffer inicial FASE 1 (default: 5)
  ALGORITHM_PRELOAD_THRESHOLD: 'algorithm_preload_threshold', // Umbral para disparar precarga (default: 3)
  ALGORITHM_CRITICAL_SONGS: 'algorithm_critical_songs',     // Canciones críticas a agregar (default: 5)

  // 🎯 PESOS DEL SCORING (0-100, se convierte a 0.0-1.0)
  WEIGHT_GENRE: 'weight_genre',               // Peso de similitud de género (default: 30)
  WEIGHT_POPULARITY: 'weight_popularity',     // Peso de popularidad (default: 20)
  WEIGHT_ARTIST: 'weight_artist',             // Peso de mismo artista (default: 10)
  WEIGHT_NOVELTY: 'weight_novelty',           // Peso de novedad (default: 20)
  WEIGHT_AFFINITY: 'weight_affinity',         // Peso de afinidad de usuario (default: 20)

  CATALOG_SIZE: 'catalog_size',                             // Total de canciones en el catálogo (auto-calculado)
  CATALOG_SMALL_THRESHOLD: 'catalog_small_threshold',       // Umbral para "catálogo pequeño" (default: 150)

  // 🆙 CONTROL DE VERSIONES
  MIN_REQUIRED_BUILD: 'min_required_build',
  LATEST_BUILD: 'latest_build',
  STORE_URL: 'store_url',
} as const;

export type SettingKey = typeof SettingKeys[keyof typeof SettingKeys];











