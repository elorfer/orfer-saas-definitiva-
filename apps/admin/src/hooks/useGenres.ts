import { useMutation, useQuery, useQueryClient } from 'react-query';
import { toast } from 'react-hot-toast';
import axios from 'axios';

import { apiClient } from '@/lib/api';

const GENRES_QUERY_KEY = 'genres';

export interface GenreModel {
  id: string;
  name: string;
  description?: string;
  colorHex?: string;
  createdAt: string;
  songCount?: number;
  albumCount?: number;
}

interface GenresResponse {
  genres: GenreModel[];
  total: number;
  page?: number;
  limit?: number;
  totalPages?: number;
}

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

export const useGenres = ({ page = 1, limit = 50, all = false, enabled = true }: {
  page?: number;
  limit?: number;
  all?: boolean;
  enabled?: boolean;
} = {}) => {
  return useQuery<GenresResponse, Error>(
    [GENRES_QUERY_KEY, page, limit, all],
    async () => {
      const response = await apiClient.getGenres(page, limit, all);
      return response.data;
    },
    {
      keepPreviousData: true,
      enabled,
      retry: 1,
      onError: (error) => {
        console.error('[useGenres] Error al obtener géneros:', error);
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useGenre = (id: string | null, enabled = true) => {
  return useQuery<GenreModel, Error>(
    [GENRES_QUERY_KEY, id],
    async () => {
      if (!id) throw new Error('ID requerido');
      const response = await apiClient.getGenre(id);
      return response.data;
    },
    {
      enabled: enabled && !!id,
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useCreateGenre = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (data: { name: string; description?: string; colorHex?: string }) => {
      const response = await apiClient.createGenre(data);
      return response.data;
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries([GENRES_QUERY_KEY]);
        toast.success('Género creado exitosamente');
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useUpdateGenre = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async ({ id, data }: { id: string; data: { name?: string; description?: string; colorHex?: string } }) => {
      const response = await apiClient.updateGenre(id, data);
      return response.data;
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries([GENRES_QUERY_KEY]);
        toast.success('Género actualizado exitosamente');
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useDeleteGenre = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (id: string) => {
      await apiClient.deleteGenre(id);
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries([GENRES_QUERY_KEY]);
        toast.success('Género eliminado exitosamente');
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useSearchGenres = (query: string, limit = 20, enabled = true) => {
  return useQuery<{ genres: GenreModel[]; total: number }, Error>(
    [GENRES_QUERY_KEY, 'search', query, limit],
    async () => {
      const response = await apiClient.searchGenres(query, limit);
      return response.data;
    },
    {
      enabled: enabled && query.trim().length > 0,
      onError: (error) => {
        // No mostrar toast en búsqueda para no ser intrusivo
        console.error('Error al buscar géneros:', error);
      },
    }
  );
};

