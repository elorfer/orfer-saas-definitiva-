import { UserRole } from '../../../common/entities/user.entity';

export interface JwtPayload {
  sub: string; // user id
  email: string;
  username: string;
  role: UserRole;
  iat?: number;
  exp?: number;
}









