import axios from 'axios';
import { useQuery } from 'react-query';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';

export interface GlobalStats {
  totalUsers: number;
  totalArtists: number;
  totalSongs: number;
  totalStreams: number;
  totalPlaylists?: number;
  verifiedUsers?: number;
  activeUsers?: number;
  featuredArtists?: number;
  publishedSongs?: number;
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
  return 'Error al cargar estadísticas';
};

/**
 * Hook profesional para obtener estadísticas globales del sistema
 * Incluye manejo de errores, cache y refetch automático
 */
export const useGlobalStats = (enabled = true) => {
  return useQuery<GlobalStats, Error>(
    'globalStats',
    async () => {
      try {
        const response = await apiClient.getGlobalStats();
        const data = response.data;
        
        return {
          totalUsers: data?.totalUsers ?? 0,
          totalArtists: data?.totalArtists ?? 0,
          totalSongs: data?.totalSongs ?? 0,
          totalStreams: data?.totalStreams ?? 0,
          totalPlaylists: data?.totalPlaylists ?? 0,
          verifiedUsers: data?.verifiedUsers ?? 0,
          activeUsers: data?.activeUsers ?? 0,
          featuredArtists: data?.featuredArtists ?? 0,
          publishedSongs: data?.publishedSongs ?? 0,
        };
      } catch (error) {
        console.error('Error fetching global stats:', error);
        throw error;
      }
    },
    {
      enabled,
      staleTime: 30000, // Los datos son válidos por 30 segundos
      refetchInterval: 60000, // Refrescar cada minuto
      retry: 2,
      retryDelay: 1000,
      onError: (error) => {
        // Solo mostrar error en consola, no hacer toast para no ser molesto
        console.error('Error en useGlobalStats:', extractErrorMessage(error));
      },
    }
  );
};

