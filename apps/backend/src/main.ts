import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger, LogLevel } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';
import { NestExpressApplication } from '@nestjs/platform-express';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { join } from 'path';
// import * as compression from 'compression';
import { AppModule } from './app.module';

async function bootstrap() {
  const configService = new ConfigService();
  const isProduction = configService.get<string>('NODE_ENV') === 'production';

  // ✅ OPTIMIZACIÓN PRODUCCIÓN: Configurar logger según entorno
  // En producción solo errores y warnings, en desarrollo todos los niveles
  const loggerOptions: LogLevel[] = isProduction
    ? ['error', 'warn']
    : ['log', 'error', 'warn', 'debug', 'verbose'];

  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: loggerOptions,
  });
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

  // Configurar servicio estático para canciones (compatibilidad con URLs legacy)
  app.useStaticAssets(join(process.cwd(), 'uploads', 'songs'), {
    prefix: '/songs',
    setHeaders: (res, path) => {
      // Permitir CORS para archivos estáticos
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      // Cache para archivos de audio
      if (path.endsWith('.mp3') || path.endsWith('.wav') || path.endsWith('.flac') || path.endsWith('.aac')) {
        res.setHeader('Cache-Control', 'public, max-age=86400'); // 24 horas
      }
    },
  });

  // Configurar servicio estático para anuncios de audio
  app.useStaticAssets(join(process.cwd(), 'uploads', 'ads', 'audio'), {
    prefix: '/uploads/ads/audio',
    setHeaders: (res, path) => {
      // Permitir CORS para archivos estáticos
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      // Cache para archivos de audio de anuncios
      if (path.endsWith('.mp3') || path.endsWith('.aac') || path.endsWith('.ogg')) {
        res.setHeader('Cache-Control', 'public, max-age=86400'); // 24 horas
      }
    },
  });

  // Configurar servicio estático para carátulas de anuncios
  app.useStaticAssets(join(process.cwd(), 'uploads', 'ads', 'covers'), {
    prefix: '/uploads/ads/covers',
    setHeaders: (res, path) => {
      // Permitir CORS para archivos estáticos
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      // Cache para imágenes de anuncios
      if (path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.webp')) {
        res.setHeader('Cache-Control', 'public, max-age=31536000'); // 1 año
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

  // CORS: durante desarrollo forzamos permissive CORS para diagnóstico remoto desde el teléfono
  app.enableCors({
    origin: true,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  });

  // Middleware de diagnóstico: log de headers Host/Origin para entender desde dónde llega la petición
  app.use((req: any, res: any, next: any) => {
    try {
      const hostHeader = req.headers?.host || 'unknown-host';
      const originHeader = req.headers?.origin || req.headers?.referer || 'unknown-origin';
      // Solo mostrar este log en desarrollo/diagnóstico para evitar spam en producción
      if (!isProduction) {
        // logger.debug(`[HTTP] Host: ${hostHeader} | Origin: ${originHeader}`);
      }
    } catch (e) {
      // no-op
    }
    next();
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



  // Configurar WebSocket adapter para Socket.io
  app.useWebSocketAdapter(new IoAdapter(app));

  // Prefijo global para la API
  app.setGlobalPrefix('api/v1');

  // ✅ OPTIMIZACIÓN PRODUCCIÓN: Swagger solo en desarrollo
  if (!isProduction) {
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
    SwaggerModule.setup('api/docs', app, document, {
      swaggerOptions: {
        persistAuthorization: true, // Mantener autorización entre recargas
      },
    });
  }

  const port = configService.get('PORT', 3001);
  // Escuchar en todas las interfaces para permitir acceso desde emulador Android
  // El emulador usa 10.0.2.2 para acceder al localhost del host
  const host = configService.get('HOST', '0.0.0.0');

  try {
    await app.listen(port, host);
  } catch (error: any) {
    if (error.code === 'EADDRINUSE') {
      logger.error(`❌ El puerto ${port} ya está en uso. Por favor ejecuta: npm run kill-port`);
      logger.error(`O detén el proceso manualmente con: Get-NetTCPConnection -LocalPort ${port} | Select-Object -ExpandProperty OwningProcess | Stop-Process -Force`);
      process.exit(1);
    }
    throw error;
  }

  // ✅ OPTIMIZACIÓN PRODUCCIÓN: Logs de inicio más concisos según entorno
  if (isProduction) {
    logger.log(`🚀 Vintage Music Backend iniciado en ${host}:${port}`);
  } else {
    logger.log('═══════════════════════════════════════════════════════════');
    logger.log(`🎵 Vintage Music Backend ejecutándose en ${host}:${port}`);
    logger.log(`📚 Documentación API disponible en http://localhost:${port}/api/docs`);
    logger.log(`🌐 Accesible desde emulador Android en: http://10.0.2.2:${port}`);
    logger.log('═══════════════════════════════════════════════════════════');
  }
}

bootstrap();
