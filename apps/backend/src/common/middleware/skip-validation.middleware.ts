import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

/**
 * Middleware que marca las requests de upload para que el ValidationPipe las ignore
 */
@Injectable()
export class SkipValidationMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    // Si es una request multipart/form-data (upload de archivos), marcar para saltar validación
    if (req.headers['content-type']?.includes('multipart/form-data')) {
      (req as any).skipValidation = true;
    }
    next();
  }
}





