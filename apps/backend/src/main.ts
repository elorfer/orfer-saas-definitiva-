import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
// import * as compression from 'compression';
import { AppModule } from './app.module';

async function bootstrap() {
  // Habilitar logs detallados
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: ['log', 'error', 'warn', 'debug', 'verbose'],
  });
  const configService = app.get(ConfigService);
  const logger = new Logger('Bootstrap');

  // Configurar servicio estático para archivos subidos
  // IMPORTANTE: Debe estar ANTES de Helmet para que funcione correctamente
  app.useStaticAssets(join(process.cwd(), 'uploads'), {
    prefix: '/uploads',
    setHeaders: (res, path) => {
      // Permitir CORS para archivos estáticos
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      // Cache para imágenes
      if (path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.webp')) {
        res.setHeader('Cache-Control', 'public, max-age=31536000');
      }
    },
  });
  
  // Configurar servicio estático para portadas
  app.useStaticAssets(join(process.cwd(), 'uploads', 'covers'), {
    prefix: '/uploads/covers',
    setHeaders: (res, path) => {
      // Permitir CORS para archivos estáticos
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      // Cache para imágenes
      if (path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.webp')) {
        res.setHeader('Cache-Control', 'public, max-age=31536000');
      }
    },
  });

  // Configuración de seguridad
  // Configurar Helmet para permitir imágenes desde cualquier origen
  app.use(helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    crossOriginEmbedderPolicy: false,
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'"],
        imgSrc: ["'self'", 'data:', 'http:', 'https:', 'blob:'],
        fontSrc: ["'self'", 'data:'],
        connectSrc: ["'self'", 'http:', 'https:'],
      },
    },
  }));
  // app.use(compression.default());

  // CORS
  const isProduction = configService.get<string>('NODE_ENV') === 'production';
  app.enableCors({
    origin: isProduction
      ? true // En producción, permitir todos los orígenes (necesario para apps móviles)
      : [
          'http://localhost:3000', // Admin panel (puerto alternativo)
          'http://localhost:3001', // Backend y Admin panel
          'http://localhost:3002', // Admin panel (puerto alternativo)
          'http://localhost:8080', // Flutter web
          'http://localhost:8081', // Flutter web alternativo
          'http://localhost:8082', // Flutter web alternativo
          'http://127.0.0.1:3000', // Admin panel localhost alternativo
          'http://127.0.0.1:3001', // Backend localhost
          'http://127.0.0.1:3002', // Admin panel localhost
          'http://127.0.0.1:8080', // Flutter web localhost alternativo
          'http://127.0.0.1:8081', // Flutter web localhost alternativo
          'http://10.0.2.2:3001', // Android emulator
          'http://10.0.2.2:8080', // Android emulator Flutter
        ],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  });

  // Validación global
  // Nota: forbidNonWhitelisted está deshabilitado para permitir FormData en rutas de upload
  // whitelist: true sigue filtrando campos no permitidos en otras rutas
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: false, // Deshabilitado para permitir FormData en uploads
      transform: true,
    }),
  );

  // Prefijo global para la API
  app.setGlobalPrefix('api/v1');

  // Configuración de Swagger
  const config = new DocumentBuilder()
    .setTitle('Vintage Music Streaming API')
    .setDescription('API para aplicación de streaming musical vintage')
    .setVersion('1.0')
    .addBearerAuth()
    .addTag('auth', 'Autenticación y autorización')
    .addTag('users', 'Gestión de usuarios')
    .addTag('artists', 'Gestión de artistas')
    .addTag('songs', 'Gestión de canciones')
    .addTag('playlists', 'Gestión de playlists')
    .addTag('streaming', 'Streaming de música')
    .addTag('analytics', 'Estadísticas y analytics')
    // .addTag('payments', 'Procesamiento de pagos')  // Deshabilitado - Pagos no implementados aún
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = configService.get('PORT', 3001);
  const host = configService.get('HOST', '0.0.0.0'); // Escuchar en todas las interfaces para permitir acceso desde emulador Android
  
  await app.listen(port, host);
  
  logger.log('═══════════════════════════════════════════════════════════');
  logger.log(`🎵 Vintage Music Backend ejecutándose en ${host}:${port}`);
  logger.log(`📚 Documentación API disponible en http://localhost:${port}/api/docs`);
  logger.log(`🌐 Accesible desde emulador Android en: http://10.0.2.2:${port}`);
  logger.log('═══════════════════════════════════════════════════════════');
  logger.log('✅ Logger configurado - Todos los logs serán visibles');
  logger.log('═══════════════════════════════════════════════════════════');
}

bootstrap();
