import { DataSource, DataSourceOptions } from 'typeorm';
import { config } from 'dotenv';
import { entities } from './entities';

config();

export const dataSourceOptions: DataSourceOptions = {
  type: 'postgres',
  url: process.env.DATABASE_URL || 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
  entities,
  migrations: [__dirname + '/../migrations/*{.ts,.js}'],
  synchronize: process.env.NODE_ENV === 'development',
  logging: process.env.NODE_ENV === 'development',
  // 🔧 Permite controlar SSL independientemente de NODE_ENV
  // Usa DATABASE_SSL=true para forzar SSL, o déjalo en false para local
  ssl: process.env.DATABASE_SSL === 'true'
    ? { rejectUnauthorized: false }
    : false,
};

const dataSource = new DataSource(dataSourceOptions);
export default dataSource;
