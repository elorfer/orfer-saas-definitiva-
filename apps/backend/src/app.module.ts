import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule, TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ThrottlerModule } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';
import { BullModule } from '@nestjs/bull';
// import { RedisModule } from '@nestjs/redis';

// Módulos de la aplicación
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { ArtistsModule } from './modules/artists/artists.module';
import { SongsModule } from './modules/songs/songs.module';
import { GenresModule } from './modules/genres/genres.module';
import { PlaylistsModule } from './modules/playlists/playlists.module';
import { StreamingModule } from './modules/streaming/streaming.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
// import { PaymentsModule } from './modules/payments/payments.module';  // Deshabilitado - Pagos no implementados aún
import { UploadModule } from './modules/upload/upload.module';
import { CoversModule } from './modules/covers/covers.module';
import { HealthModule } from './modules/health/health.module';
import { PublicModule } from './modules/public/public.module';
import { FeaturedModule } from './modules/featured/featured.module';
import { entities } from './database/entities';

// Configuración de la base de datos
import { dataSourceOptions } from './database/data-source';

@Module({
  imports: [
    // Configuración global
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env.local', '.env'],
    }),

    // Base de datos PostgreSQL
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService): TypeOrmModuleOptions => {
        const isProduction = configService.get<string>('NODE_ENV') === 'production';
        const sslEnv = configService.get<string>('DB_SSL');
        const sslRejectEnv = configService.get<string>('DB_SSL_REJECT_UNAUTHORIZED');
        const databaseUrl = configService.get<string>('DATABASE_URL');
        
        // Detectar si DATABASE_URL contiene parámetros SSL
        const urlHasSsl = databaseUrl?.includes('sslmode=') || databaseUrl?.includes('ssl=');
        
        // Determinar si SSL debe estar habilitado
        let sslEnabled = false;
        if (typeof sslEnv === 'string') {
          sslEnabled = ['1', 'true', 'yes', 'on'].includes(sslEnv.toLowerCase());
        } else if (urlHasSsl) {
          // Si la URL tiene parámetros SSL, habilitar SSL
          sslEnabled = true;
        } else {
          sslEnabled = isProduction;
        }
        
        // Determinar si se debe rechazar certificados no autorizados
        // Por defecto, si DB_SSL_REJECT_UNAUTHORIZED no está definido, usar false (aceptar certificados autofirmados)
        let rejectUnauthorized = false;
        if (typeof sslRejectEnv === 'string') {
          const sslRejectLower = sslRejectEnv.toLowerCase();
          rejectUnauthorized = ['1', 'true', 'yes', 'on'].includes(sslRejectLower);
        }
        
        const sslOptions = sslEnabled ? { rejectUnauthorized } : false;

        const baseOptions: TypeOrmModuleOptions = {
          type: 'postgres',
          entities,
          autoLoadEntities: true,
          synchronize: !isProduction,
          logging: !isProduction,
          connectTimeoutMS: 30000, // 30 segundos de timeout
          extra: {
            connectionTimeoutMillis: 30000,
          },
        };

        if (databaseUrl) {
          // Si la URL tiene parámetros SSL, removerlos y usar la configuración de ssl del objeto
          let cleanUrl = databaseUrl;
          if (urlHasSsl) {
            // Remover parámetros SSL de la URL para evitar conflictos
            cleanUrl = databaseUrl.replace(/[?&]sslmode=[^&]*/gi, '').replace(/[?&]ssl=[^&]*/gi, '');
            // Si quedó un ? al final sin parámetros, removerlo
            cleanUrl = cleanUrl.replace(/\?$/, '');
          }
          
          return {
            ...baseOptions,
            url: cleanUrl,
            ssl: sslOptions,
          };
        }

        return {
          ...baseOptions,
          host: configService.get<string>('DB_HOST') ?? 'localhost',
          port: Number(configService.get<string>('DB_PORT') ?? '5432'),
          username: configService.get<string>('DB_USERNAME') ?? 'vintage_user',
          password: configService.get<string>('DB_PASSWORD') ?? 'vintage_password_2024',
          database: configService.get<string>('DB_DATABASE') ?? 'vintage_music',
          ssl: sslOptions,
        };
      },
      inject: [ConfigService],
    }),

    // Redis para estadísticas en tiempo real
    // RedisModule.forRootAsync({
    //   imports: [ConfigModule],
    //   useFactory: (configService: ConfigService) => ({
    //     url: configService.get('REDIS_URL'),
    //   }),
    //   inject: [ConfigService],
    // }),

    // Rate limiting
    ThrottlerModule.forRoot([
      {
        ttl: 60000, // 1 minuto
        limit: 100, // 100 requests por minuto
      },
    ]),

    // Tareas programadas
    ScheduleModule.forRoot(),

    // BullMQ para colas de procesamiento
    // Nota: Solo se inicializa si Redis está disponible
    BullModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => {
        // Priorizar REDIS_URL si está disponible (para Docker)
        const redisUrl = configService.get<string>('REDIS_URL');
        
        let redisConfig: any = {
          maxRetriesPerRequest: null,
          enableReadyCheck: false,
        };
        
        if (redisUrl) {
          // Parsear REDIS_URL (formato: redis://[password@]host:port)
          const url = new URL(redisUrl);
          redisConfig.host = url.hostname;
          redisConfig.port = parseInt(url.port) || 6379;
          if (url.password) {
            redisConfig.password = url.password;
          }
        } else {
          // Fallback a REDIS_HOST y REDIS_PORT
          redisConfig.host = configService.get<string>('REDIS_HOST') || 'localhost';
          redisConfig.port = configService.get<number>('REDIS_PORT') || 6379;
          
          const password = configService.get<string>('REDIS_PASSWORD');
          if (password) {
            redisConfig.password = password;
          }
        }
        
        return {
          redis: redisConfig,
        };
      },
      inject: [ConfigService],
    }),

    // Módulos de la aplicación
    HealthModule,
    AuthModule,
    UsersModule,
    ArtistsModule,
    SongsModule,
    GenresModule,
    PlaylistsModule,
    StreamingModule,
    AnalyticsModule,
    // PaymentsModule,  // Deshabilitado - Pagos no implementados aún
    UploadModule,
    CoversModule,
    PublicModule,
    FeaturedModule,
  ],
})
export class AppModule {}
