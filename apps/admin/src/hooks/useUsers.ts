import axios from 'axios';
import { useMutation, useQuery, useQueryClient } from 'react-query';
import { toast } from 'react-hot-toast';

import { apiClient } from '@/lib/api';
import {
  ArtistSummary,
  CreateUserInput,
  UpdateUserInput,
  UseUsersParams,
  UserModel,
  UsersResponse,
} from '@/types/user';

const USERS_QUERY_KEY = 'users';

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

export const useUsers = ({ page = 1, limit = 10, enabled = true }: UseUsersParams = {}) => {
  return useQuery<UsersResponse, Error>(
    [USERS_QUERY_KEY, page, limit],
    async () => {
      const response = await apiClient.getUsers(page, limit);
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

export const useUpdateUser = () => {
  const queryClient = useQueryClient();

  return useMutation<UserModel, unknown, { id: string; data: UpdateUserInput }>(
    async ({ id, data }) => {
      const response = await apiClient.updateUser(id, data);
      return mapUser(response.data);
    },
    {
      onSuccess: () => {
        toast.success('Usuario actualizado correctamente');
        queryClient.invalidateQueries(USERS_QUERY_KEY);
      },
      onError: (error: unknown) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useDeleteUser = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (id: string) => {
      await apiClient.deleteUser(id);
      return id;
    },
    {
      onSuccess: () => {
        toast.success('Usuario eliminado');
        queryClient.invalidateQueries(USERS_QUERY_KEY);
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useCreateUser = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (data: CreateUserInput) => {
      const response = await apiClient.createUser(data);
      return mapUser(response.data.user);
    },
    {
      onSuccess: () => {
        toast.success('Usuario creado correctamente');
        queryClient.invalidateQueries(USERS_QUERY_KEY);
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useActivateUser = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (id: string) => {
      const response = await apiClient.activateUser(id);
      return mapUser(response.data);
    },
    {
      onSuccess: () => {
        toast.success('Usuario activado');
        queryClient.invalidateQueries(USERS_QUERY_KEY);
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useDeactivateUser = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (id: string) => {
      const response = await apiClient.deactivateUser(id);
      return mapUser(response.data);
    },
    {
      onSuccess: () => {
        toast.success('Usuario desactivado');
        queryClient.invalidateQueries(USERS_QUERY_KEY);
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useVerifyUser = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (id: string) => {
      const response = await apiClient.verifyUser(id);
      return mapUser(response.data);
    },
    {
      onSuccess: () => {
        toast.success('Usuario verificado');
        queryClient.invalidateQueries(USERS_QUERY_KEY);
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

