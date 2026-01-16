import { useQuery, useMutation, useQueryClient } from 'react-query';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';

export interface AudioAd {
  id: string;
  title: string;
  description?: string;
  audioUrl: string;
  coverImageUrl?: string;
  advertiserName: string;
  clickThroughUrl?: string;
  durationSeconds: number;
  fileSizeBytes: number;
  status: 'draft' | 'active' | 'paused' | 'expired';
  targeting: 'all' | 'genre' | 'artist' | 'playlist';
  targetGenres?: string[];
  targetArtists?: string[];
  targetPlaylists?: string[];
  frequencyPerHour: number;
  maxPlaysPerDay?: number;
  startDate?: string;
  endDate?: string;
  priority: number;
  isSkippable: boolean;
  skipAfterSeconds: number;
  totalPlays: number;
  totalClicks: number;
  createdAt: string;
  updatedAt: string;
}

export interface AdStats {
  totalPlays: number;
  totalClicks: number;
  completionRate: number;
  skipRate: number;
  clickThroughRate: number;
  averageDuration: number;
  recentPlays: any[];
}

export function useAds(page = 1, limit = 10, status?: string) {
  return useQuery(
    ['ads', page, limit, status],
    async () => {
      const response = await apiClient.getAds(page, limit, status);
      return response.data;
    }
  );
}

export function useAd(id: string) {
  return useQuery(
    ['ad', id],
    async () => {
      const response = await apiClient.getAd(id);
      return response.data;
    },
    {
      enabled: !!id,
    }
  );
}

export function useCreateAd() {
  const queryClient = useQueryClient();

  return useMutation(
    async (data: any) => {
      const response = await apiClient.createAd(data);
      return response.data;
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['ads']);
        toast.success('Anuncio creado exitosamente');
      },
      onError: (error: any) => {
        toast.error(error.response?.data?.message || 'Error al crear anuncio');
      },
    }
  );
}

export function useUpdateAd() {
  const queryClient = useQueryClient();

  return useMutation(
    async ({ id, data }: { id: string; data: any }) => {
      const response = await apiClient.updateAd(id, data);
      return response.data;
    },
    {
      onSuccess: (_, variables) => {
        queryClient.invalidateQueries(['ads']);
        queryClient.invalidateQueries(['ad', variables.id]);
        toast.success('Anuncio actualizado exitosamente');
      },
      onError: (error: any) => {
        toast.error(error.response?.data?.message || 'Error al actualizar anuncio');
      },
    }
  );
}

export function useDeleteAd() {
  const queryClient = useQueryClient();

  return useMutation(
    async (id: string) => {
      await apiClient.deleteAd(id);
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['ads']);
        toast.success('Anuncio eliminado exitosamente');
      },
      onError: (error: any) => {
        toast.error(error.response?.data?.message || 'Error al eliminar anuncio');
      },
    }
  );
}

export function useActivateAd() {
  const queryClient = useQueryClient();

  return useMutation(
    async (id: string) => {
      const response = await apiClient.activateAd(id);
      return response.data;
    },
    {
      onSuccess: (_, id) => {
        queryClient.invalidateQueries(['ads']);
        queryClient.invalidateQueries(['ad', id]);
        toast.success('Anuncio activado exitosamente');
      },
      onError: (error: any) => {
        toast.error(error.response?.data?.message || 'Error al activar anuncio');
      },
    }
  );
}

export function usePauseAd() {
  const queryClient = useQueryClient();

  return useMutation(
    async (id: string) => {
      const response = await apiClient.pauseAd(id);
      return response.data;
    },
    {
      onSuccess: (_, id) => {
        queryClient.invalidateQueries(['ads']);
        queryClient.invalidateQueries(['ad', id]);
        toast.success('Anuncio pausado exitosamente');
      },
      onError: (error: any) => {
        toast.error(error.response?.data?.message || 'Error al pausar anuncio');
      },
    }
  );
}

export function useAdStats(id: string) {
  return useQuery(
    ['ad-stats', id],
    async () => {
      const response = await apiClient.getAdStats(id);
      return response.data as AdStats;
    },
    {
      enabled: !!id,
    }
  );
}

// ============================================
// Hooks para configuración de frecuencia de anuncios
// ============================================

export interface AdFrequencyResponse {
  frequency: number;
}

/**
 * Hook para obtener la frecuencia de anuncios actual
 */
export function useAdFrequency() {
  return useQuery<AdFrequencyResponse>(
    ['ad-frequency'],
    async () => {
      const response = await apiClient.getAdFrequency();
      return response.data;
    },
    {
      staleTime: 30000, // 30 segundos de cache
      refetchOnWindowFocus: false,
    }
  );
}

/**
 * Hook para actualizar la frecuencia de anuncios
 */
export function useUpdateAdFrequency() {
  const queryClient = useQueryClient();

  return useMutation(
    async (value: number) => {
      const response = await apiClient.updateAdFrequency(value);
      return response.data;
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['ad-frequency']);
        toast.success('Frecuencia de anuncios actualizada exitosamente');
      },
      onError: (error: any) => {
        toast.error(error.response?.data?.message || 'Error al actualizar la frecuencia');
      },
    }
  );
}
