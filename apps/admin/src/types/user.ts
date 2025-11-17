export type UserRole = 'admin' | 'artist' | 'user';

export type SubscriptionStatus = 'active' | 'inactive' | 'cancelled' | 'expired';

export interface ArtistSummary {
  id: string;
  userId?: string;
  stageName?: string;
  bio?: string;
  websiteUrl?: string;
  socialLinks?: Record<string, unknown> | null;
  totalFollowers?: number;
  totalStreams?: number;
  monthlyListeners?: number;
  verificationStatus?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface UserModel {
  id: string;
  email: string;
  username: string;
  firstName: string;
  lastName: string;
  avatarUrl?: string | null;
  role: UserRole;
  subscriptionStatus: SubscriptionStatus;
  subscriptionExpiresAt?: string | null;
  isVerified: boolean;
  isActive: boolean;
  lastLoginAt?: string | null;
  createdAt: string;
  updatedAt: string;
  artist?: ArtistSummary | null;
}

export interface UsersResponse {
  users: UserModel[];
  total: number;
}

export interface CreateUserInput {
  email: string;
  username: string;
  password: string;
  firstName: string;
  lastName: string;
  role: UserRole;
  stageName?: string;
}

export interface UseUsersParams {
  page?: number;
  limit?: number;
  enabled?: boolean;
}

export interface UpdateUserInput {
  email?: string;
  username?: string;
  firstName?: string;
  lastName?: string;
  avatarUrl?: string;
  role?: UserRole;
  subscriptionStatus?: SubscriptionStatus;
  isVerified?: boolean;
  isActive?: boolean;
}

