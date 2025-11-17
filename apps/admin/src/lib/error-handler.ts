/**
 * Sistema de manejo de errores centralizado
 * Para desarrollo y producción
 */

import { logger } from './logger';
import { config } from '@/config/env';

export interface AppError extends Error {
  statusCode?: number;
  code?: string;
  context?: string;
  metadata?: Record<string, any>;
}

export class CustomError extends Error implements AppError {
  public statusCode: number;
  public code: string;
  public context?: string;
  public metadata?: Record<string, any>;

  constructor(
    message: string,
    statusCode: number = 500,
    code: string = 'INTERNAL_ERROR',
    context?: string,
    metadata?: Record<string, any>
  ) {
    super(message);
    this.name = 'CustomError';
    this.statusCode = statusCode;
    this.code = code;
    this.context = context;
    this.metadata = metadata;

    // Mantener el stack trace
    Error.captureStackTrace(this, this.constructor);
  }
}

// Errores predefinidos
export const AppErrors = {
  // Autenticación
  UNAUTHORIZED: (message: string = 'No autorizado') => 
    new CustomError(message, 401, 'UNAUTHORIZED', 'AUTH'),
  
  FORBIDDEN: (message: string = 'Acceso denegado') => 
    new CustomError(message, 403, 'FORBIDDEN', 'AUTH'),
  
  INVALID_CREDENTIALS: (message: string = 'Credenciales inválidas') => 
    new CustomError(message, 401, 'INVALID_CREDENTIALS', 'AUTH'),
  
  TOKEN_EXPIRED: (message: string = 'Token expirado') => 
    new CustomError(message, 401, 'TOKEN_EXPIRED', 'AUTH'),
  
  // Validación
  VALIDATION_ERROR: (message: string = 'Error de validación') => 
    new CustomError(message, 400, 'VALIDATION_ERROR', 'VALIDATION'),
  
  MISSING_REQUIRED_FIELD: (field: string) => 
    new CustomError(`Campo requerido faltante: ${field}`, 400, 'MISSING_REQUIRED_FIELD', 'VALIDATION'),
  
  INVALID_FORMAT: (field: string, format: string) => 
    new CustomError(`Formato inválido para ${field}: debe ser ${format}`, 400, 'INVALID_FORMAT', 'VALIDATION'),
  
  // Base de datos
  DATABASE_ERROR: (message: string = 'Error de base de datos') => 
    new CustomError(message, 500, 'DATABASE_ERROR', 'DATABASE'),
  
  RECORD_NOT_FOUND: (resource: string) => 
    new CustomError(`${resource} no encontrado`, 404, 'RECORD_NOT_FOUND', 'DATABASE'),
  
  DUPLICATE_RECORD: (resource: string, field: string) => 
    new CustomError(`${resource} ya existe con ${field}`, 409, 'DUPLICATE_RECORD', 'DATABASE'),
  
  // Archivos
  FILE_TOO_LARGE: (maxSize: string) => 
    new CustomError(`Archivo demasiado grande. Máximo: ${maxSize}`, 413, 'FILE_TOO_LARGE', 'UPLOAD'),
  
  INVALID_FILE_TYPE: (allowedTypes: string[]) => 
    new CustomError(`Tipo de archivo no permitido. Tipos permitidos: ${allowedTypes.join(', ')}`, 400, 'INVALID_FILE_TYPE', 'UPLOAD'),
  
  // Rate Limiting
  RATE_LIMIT_EXCEEDED: (message: string = 'Límite de requests excedido') => 
    new CustomError(message, 429, 'RATE_LIMIT_EXCEEDED', 'RATE_LIMIT'),
  
  // Servicio externo
  EXTERNAL_SERVICE_ERROR: (service: string, message: string = 'Error en servicio externo') => 
    new CustomError(`${service}: ${message}`, 502, 'EXTERNAL_SERVICE_ERROR', 'EXTERNAL_SERVICE'),
  
  // Configuración
  CONFIGURATION_ERROR: (message: string = 'Error de configuración') => 
    new CustomError(message, 500, 'CONFIGURATION_ERROR', 'CONFIG'),
};

export class ErrorHandler {
  static handle(error: Error | AppError, context?: string): AppError {
    let appError: AppError;

    if (error instanceof CustomError) {
      appError = error;
    } else if (error.name === 'ValidationError') {
      appError = AppErrors.VALIDATION_ERROR(error.message);
    } else if (error.name === 'UnauthorizedError') {
      appError = AppErrors.UNAUTHORIZED(error.message);
    } else if (error.name === 'ForbiddenError') {
      appError = AppErrors.FORBIDDEN(error.message);
    } else if (error.name === 'NotFoundError') {
      appError = new CustomError(error.message, 404, 'NOT_FOUND');
    } else {
      appError = new CustomError(
        config.environment.isProduction ? 'Error interno del servidor' : error.message,
        500,
        'INTERNAL_ERROR',
        context,
        config.environment.isDevelopment ? { originalError: error.message, stack: error.stack } : undefined
      );
    }

    // Log del error
    const statusCode = appError.statusCode ?? 500;

    const logPayload = {
      code: appError.code,
      statusCode,
      metadata: appError.metadata,
    };

    if (statusCode >= 500) {
      logger.error(appError.message, appError.context || context, logPayload);
    } else {
      logger.warn(appError.message, appError.context || context, logPayload);
    }

    return appError;
  }

  static formatForClient(error: AppError) {
    return {
      message: error.message,
      code: error.code,
      statusCode: error.statusCode,
      ...(config.environment.isDevelopment && {
        context: error.context,
        metadata: error.metadata,
        stack: error.stack,
      }),
    };
  }
}

// Hook para manejo de errores en React
export const useErrorHandler = () => {
  const handleError = (error: Error | AppError, context?: string) => {
    const appError = ErrorHandler.handle(error, context);
    return ErrorHandler.formatForClient(appError);
  };

  return { handleError };
};

// Wrapper para async functions
export const withErrorHandling = <T extends any[], R>(
  fn: (...args: T) => Promise<R>,
  context?: string
) => {
  return async (...args: T): Promise<R> => {
    try {
      return await fn(...args);
    } catch (error) {
      throw ErrorHandler.handle(error as Error, context);
    }
  };
};


