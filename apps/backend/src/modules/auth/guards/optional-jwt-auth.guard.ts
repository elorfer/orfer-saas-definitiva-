import { Injectable, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * 🔓 Guard JWT Opcional
 * 
 * Similar a JwtAuthGuard, pero NO lanza error si el usuario no está autenticado.
 * Útil para endpoints que funcionan tanto para usuarios autenticados como anónimos,
 * pero ofrecen funcionalidad adicional para usuarios autenticados.
 * 
 * Si el token es válido: req.user contendrá la información del usuario
 * Si no hay token o es inválido: req.user será undefined (no lanza error)
 */
@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    // Llamar al guard padre
    return super.canActivate(context);
  }

  handleRequest(err: any, user: any) {
    // Si hay error o no hay usuario, simplemente retornar null (no lanzar error)
    // Esto permite que el endpoint funcione sin autenticación
    if (err || !user) {
      return null;
    }
    return user;
  }
}
