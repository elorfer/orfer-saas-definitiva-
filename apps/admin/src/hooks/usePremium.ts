import { useQuery } from 'react-query';
import { toast } from 'react-hot-toast';
import axios from 'axios';

import { apiClient } from '@/lib/api';
import type { UsersResponse, UserModel, ArtistSummary } from '@/types/user';

const mapArtist = (artist: any): ArtistSummary => ({
  id: artist?.id ?? '',
  userId: artist?.userId ?? artist?.user_id ?? undefined,
  stageName: artist?.stageName ?? artist?.stage_name ?? undefined,
  bio: artist?.bio ?? undefined,
  websiteUrl: artist?.websiteUrl ?? artist?.website_url ?? undefined,
  socialLinks: artist?.socialLinks ?? artist?.social_links ?? null,
  totalFollowers: artist?.totalFollowers ?? artist?.total_followers ?? undefined,
  totalStreams: artist?.totalStreams ?? artist?.total_streams ?? undefined,
  monthlyListeners: artist?.monthlyListeners ?? artist?.monthly_listeners ?? undefined,
  verificationStatus: artist?.verificationStatus ?? artist?.verification_status ?? undefined,
  createdAt: artist?.createdAt ?? artist?.created_at ?? undefined,
  updatedAt: artist?.updatedAt ?? artist?.updated_at ?? undefined,
});

const mapUser = (user: any): UserModel => ({
  id: user?.id ?? '',
  email: user?.email ?? '',
  username: user?.username ?? '',
  firstName: user?.firstName ?? user?.first_name ?? '',
  lastName: user?.lastName ?? user?.last_name ?? '',
  avatarUrl: user?.avatarUrl ?? user?.avatar_url ?? null,
  role: user?.role ?? 'user',
  subscriptionStatus: user?.subscriptionStatus ?? user?.subscription_status ?? 'inactive',
  subscriptionSource: user?.subscriptionSource ?? user?.subscription_source ?? 'manual',
  subscriptionExpiresAt: user?.subscriptionExpiresAt ?? user?.subscription_expires_at ?? null,
  isVerified: user?.isVerified ?? user?.is_verified ?? false,
  isActive: user?.isActive ?? user?.is_active ?? false,
  lastLoginAt: user?.lastLoginAt ?? user?.last_login_at ?? null,
  createdAt: user?.createdAt ?? user?.created_at ?? new Date().toISOString(),
  updatedAt: user?.updatedAt ?? user?.updated_at ?? new Date().toISOString(),
  artist: user?.artist ? mapArtist(user.artist) : null,
});

const mapUsersResponse = (data: any): UsersResponse => ({
  users: Array.isArray(data?.users) ? data.users.map(mapUser) : [],
  total: Number(data?.total ?? data?.users?.length ?? 0),
});

const PREMIUM_QUERY_KEY = 'premium';

const extractErrorMessage = (error: unknown): string => {
  if (axios.isAxiosError(error)) {
    const message = error.response?.data?.message;
    if (Array.isArray(message)) {
      return message[0];
    }
    if (typeof message === 'string') {
      return message;
    }
  }
  return 'Ocurrió un error inesperado';
};

export const usePremiumUsers = ({ page = 1, limit = 10, enabled = true }: { page?: number; limit?: number; enabled?: boolean } = {}) => {
  return useQuery<UsersResponse, Error>(
    [PREMIUM_QUERY_KEY, 'list', page, limit],
    async () => {
      const response = await apiClient.getPremiumUsers(page, limit);
      return mapUsersResponse(response.data);
    },
    {
      keepPreviousData: true,
      enabled,
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const usePremiumUsersExpiringSoon = (days: number = 30, enabled: boolean = true) => {
  return useQuery<UsersResponse, Error>(
    [PREMIUM_QUERY_KEY, 'expiring-soon', days],
    async () => {
      const response = await apiClient.getPremiumUsersExpiringSoon(days);
      return mapUsersResponse(response.data);
    },
    {
      enabled,
      refetchOnWindowFocus: true,
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const usePremiumStats = (enabled: boolean = true) => {
  return useQuery<{ total: number; expiringSoon: number; recentlyAdded: number }, Error>(
    [PREMIUM_QUERY_KEY, 'stats'],
    async () => {
      const response = await apiClient.getPremiumStats();
      return response.data;
    },
    {
      enabled,
      refetchOnWindowFocus: true,
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useManualRevenueStats = (enabled: boolean = true) => {
  return useQuery<{ totalManualRevenue: number }, Error>(
    [PREMIUM_QUERY_KEY, 'revenue-stats'],
    async () => {
      const response = await apiClient.getManualRevenueStats();
      return response.data;
    },
    {
      enabled,
      refetchOnWindowFocus: true,
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useMonthlyRevenueStats = (enabled: boolean = true) => {
  return useQuery<{ month: string; total: number; count: number }[], Error>(
    [PREMIUM_QUERY_KEY, 'monthly-revenue'],
    async () => {
      const response = await apiClient.getMonthlyRevenueStats();
      return response.data;
    },
    {
      enabled,
      refetchOnWindowFocus: true,
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

