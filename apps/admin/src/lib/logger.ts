/**
 * Sistema de logging profesional
 * Configurado para desarrollo y producción
 */

import { config } from '@/config/env';

export enum LogLevel {
  ERROR = 'error',
  WARN = 'warn',
  INFO = 'info',
  DEBUG = 'debug',
}

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  context?: string;
  metadata?: Record<string, any>;
  userId?: string;
  requestId?: string;
}

class Logger {
  private logLevel: LogLevel;

  constructor() {
    this.logLevel = this.parseLogLevel(config.logging.level);
  }

  private parseLogLevel(level: string): LogLevel {
    switch (level.toLowerCase()) {
      case 'error': return LogLevel.ERROR;
      case 'warn': return LogLevel.WARN;
      case 'info': return LogLevel.INFO;
      case 'debug': return LogLevel.DEBUG;
      default: return LogLevel.INFO;
    }
  }

  private shouldLog(level: LogLevel): boolean {
    const levels = [LogLevel.ERROR, LogLevel.WARN, LogLevel.INFO, LogLevel.DEBUG];
    const currentLevelIndex = levels.indexOf(this.logLevel);
    const messageLevelIndex = levels.indexOf(level);
    return messageLevelIndex <= currentLevelIndex;
  }

  private formatMessage(entry: LogEntry): string {
    const { timestamp, level, message, context, metadata, userId, requestId } = entry;
    
    let formatted = `[${timestamp}] ${level.toUpperCase()}`;
    
    if (context) formatted += ` [${context}]`;
    if (userId) formatted += ` [user:${userId}]`;
    if (requestId) formatted += ` [req:${requestId}]`;
    
    formatted += `: ${message}`;
    
    if (metadata && Object.keys(metadata).length > 0) {
      formatted += ` | ${JSON.stringify(metadata)}`;
    }
    
    return formatted;
  }

  private log(level: LogLevel, message: string, context?: string, metadata?: Record<string, any>) {
    if (!this.shouldLog(level)) return;

    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      context,
      metadata,
    };

    const formattedMessage = this.formatMessage(entry);

    // En desarrollo, usar console con colores
    if (config.environment.isDevelopment) {
      this.logToConsole(level, formattedMessage);
    } else {
      // En producción, enviar a servicio de logging
      this.logToProduction(entry);
    }
  }

  private logToConsole(level: LogLevel, message: string) {
    const colors = {
      [LogLevel.ERROR]: '\x1b[31m', // Rojo
      [LogLevel.WARN]: '\x1b[33m',  // Amarillo
      [LogLevel.INFO]: '\x1b[36m',  // Cyan
      [LogLevel.DEBUG]: '\x1b[90m', // Gris
    };

    const reset = '\x1b[0m';
    console.log(`${colors[level]}${message}${reset}`);
  }

  private logToProduction(entry: LogEntry) {
    // Aquí puedes integrar con servicios como:
    // - Winston
    // - LogRocket
    // - Sentry
    // - CloudWatch
    // - Datadog
    
    console.log(JSON.stringify(entry));
  }

  // Métodos públicos
  error(message: string, context?: string, metadata?: Record<string, any>) {
    this.log(LogLevel.ERROR, message, context, metadata);
  }

  warn(message: string, context?: string, metadata?: Record<string, any>) {
    this.log(LogLevel.WARN, message, context, metadata);
  }

  info(message: string, context?: string, metadata?: Record<string, any>) {
    this.log(LogLevel.INFO, message, context, metadata);
  }

  debug(message: string, context?: string, metadata?: Record<string, any>) {
    this.log(LogLevel.DEBUG, message, context, metadata);
  }

  // Método para logging de requests HTTP
  httpRequest(method: string, url: string, statusCode: number, duration: number, userId?: string) {
    this.info(`${method} ${url} - ${statusCode}`, 'HTTP', {
      method,
      url,
      statusCode,
      duration: `${duration}ms`,
      userId,
    });
  }

  // Método para logging de autenticación
  auth(action: string, email: string, success: boolean, metadata?: Record<string, any>) {
    const level = success ? LogLevel.INFO : LogLevel.WARN;
    this.log(level, `Auth ${action}`, 'AUTH', {
      email,
      success,
      ...metadata,
    });
  }

  // Método para logging de errores de base de datos
  database(operation: string, table: string, error?: Error, metadata?: Record<string, any>) {
    if (error) {
      this.error(`Database ${operation} failed on ${table}`, 'DATABASE', {
        operation,
        table,
        error: error.message,
        ...metadata,
      });
    } else {
      this.debug(`Database ${operation} on ${table}`, 'DATABASE', metadata);
    }
  }
}

// Singleton instance
export const logger = new Logger();

// Helper para logging en componentes React
export const useLogger = (context: string) => {
  return {
    error: (message: string, metadata?: Record<string, any>) => logger.error(message, context, metadata),
    warn: (message: string, metadata?: Record<string, any>) => logger.warn(message, context, metadata),
    info: (message: string, metadata?: Record<string, any>) => logger.info(message, context, metadata),
    debug: (message: string, metadata?: Record<string, any>) => logger.debug(message, context, metadata),
  };
};


