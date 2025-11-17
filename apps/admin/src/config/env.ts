/**
 * Configuración centralizada de variables de entorno
 * Separada por entorno (desarrollo, staging, producción)
 */

export interface Config {
  // NextAuth
  nextAuth: {
    url: string;
    secret: string;
  };
  
  // API
  api: {
    baseUrl: string;
    publicUrl: string;
  };
  
  // Base de datos
  database: {
    url: string;
  };
  
  // Entorno
  environment: {
    nodeEnv: string;
    isDevelopment: boolean;
    isProduction: boolean;
  };
  
  // Seguridad
  security: {
    bcryptRounds: number;
    jwtSecret: string;
    jwtExpiresIn: string;
  };
  
  // Rate Limiting
  rateLimit: {
    ttl: number;
    max: number;
  };
  
  // File Upload
  upload: {
    maxFileSize: number;
    allowedFileTypes: string[];
  };
  
  // Logging
  logging: {
    level: string;
  };
  
  // Redis
  redis: {
    url: string;
  };
  
  // Email
  email: {
    smtp: {
      host: string;
      port: number;
      user: string;
      pass: string;
    };
    fromEmail: string;
  };
}

const normalizeApiBaseUrl = (url?: string) => {
  const fallback = 'http://localhost:3001';
  const rawUrl = (url && url.trim().length > 0 ? url : fallback).trim();
  const trimmed = rawUrl.replace(/\/+$/, '');

  if (/\/api\/v\d+$/i.test(trimmed)) {
    return trimmed;
  }

  if (/\/api$/i.test(trimmed)) {
    return `${trimmed}/v1`;
  }

  return `${trimmed}/api/v1`;
};

const getConfig = (): Config => {
  const nodeEnv = process.env.NODE_ENV || 'development';
  const isDevelopment = nodeEnv === 'development';
  const isProduction = nodeEnv === 'production';

  return {
    nextAuth: {
      url: process.env.NEXTAUTH_URL || 'http://localhost:3002',
      secret: process.env.NEXTAUTH_SECRET || 'vintage-music-admin-secret-key-2024',
    },
    
    api: {
      baseUrl: normalizeApiBaseUrl(process.env.API_BASE_URL),
      publicUrl: normalizeApiBaseUrl(process.env.NEXT_PUBLIC_API_URL),
    },
    
    database: {
      url: process.env.DATABASE_URL || 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
    },
    
    environment: {
      nodeEnv,
      isDevelopment,
      isProduction,
    },
    
    security: {
      bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS || '12'),
      jwtSecret: process.env.JWT_SECRET || 'vintage-music-jwt-secret-2024',
      jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
    },
    
    rateLimit: {
      ttl: parseInt(process.env.RATE_LIMIT_TTL || '60000'),
      max: parseInt(process.env.RATE_LIMIT_MAX || '100'),
    },
    
    upload: {
      maxFileSize: parseInt(process.env.MAX_FILE_SIZE || '10485760'), // 10MB
      allowedFileTypes: (process.env.ALLOWED_FILE_TYPES || 'image/jpeg,image/png,image/webp,audio/mpeg,audio/wav').split(','),
    },
    
    logging: {
      level: process.env.LOG_LEVEL || (isDevelopment ? 'debug' : 'info'),
    },
    
    redis: {
      url: process.env.REDIS_URL || 'redis://localhost:6379',
    },
    
    email: {
      smtp: {
        host: process.env.SMTP_HOST || '',
        port: parseInt(process.env.SMTP_PORT || '587'),
        user: process.env.SMTP_USER || '',
        pass: process.env.SMTP_PASS || '',
      },
      fromEmail: process.env.FROM_EMAIL || 'noreply@vintagemusic.com',
    },
  };
};

// Configuración singleton
export const config = getConfig();

// Validación de configuración crítica
export const validateConfig = (): void => {
  const errors: string[] = [];

  if (!config.nextAuth.secret || config.nextAuth.secret === 'your-secret-key-here') {
    errors.push('NEXTAUTH_SECRET debe estar configurado');
  }

  if (!config.security.jwtSecret || config.security.jwtSecret === 'your-jwt-secret-here') {
    errors.push('JWT_SECRET debe estar configurado');
  }

  if (config.environment.isProduction) {
    if (!config.database.url.includes('postgresql://')) {
      errors.push('DATABASE_URL debe estar configurado para producción');
    }
    
    if (!config.redis.url.includes('redis://')) {
      errors.push('REDIS_URL debe estar configurado para producción');
    }
  }

  if (errors.length > 0) {
    throw new Error(`Configuración inválida:\n${errors.join('\n')}`);
  }
};

// Ejecutar validación al cargar el módulo
if (typeof window === 'undefined') {
  try {
    validateConfig();
  } catch (error) {
    console.error('❌ Error de configuración:', error);
    if (config.environment.isProduction) {
      process.exit(1);
    }
  }
}