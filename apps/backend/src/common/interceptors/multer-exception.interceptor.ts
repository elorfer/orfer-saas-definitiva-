import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  BadRequestException,
} from '@nestjs/common';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { MulterError } from 'multer';

@Injectable()
export class MulterExceptionInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    return next.handle().pipe(
      catchError((error) => {
        if (error instanceof MulterError) {
          if (error.code === 'LIMIT_UNEXPECTED_FILE') {
            return throwError(
              () =>
                new BadRequestException(
                  'Campo de archivo no esperado. Use los campos "audio" y "cover" (opcional)',
                ),
            );
          }
          return throwError(() => new BadRequestException(`Error al subir archivo: ${error.message}`));
        }
        return throwError(() => error);
      }),
    );
  }
}





