import { PipeTransform, Injectable, ArgumentMetadata } from '@nestjs/common';

/**
 * Pipe que no hace nada, usado para deshabilitar el ValidationPipe global
 * en rutas específicas que manejan FormData
 */
@Injectable()
export class SkipValidationPipe implements PipeTransform {
  transform(value: any, metadata: ArgumentMetadata) {
    return value;
  }
}





