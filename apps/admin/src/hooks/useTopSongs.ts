import axios from 'axios';
import { useQuery } from 'react-query';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';
import { SongModel } from '@/types/song';

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
  return 'Error al cargar top canciones';
};

/**
 * Hook para obtener las canciones más populares
 */
export const useTopSongs = (limit: number = 5, enabled: boolean = true) => {
  return useQuery<SongModel[], Error>(
    ['topSongs', limit],
    async () => {
      try {
        const response = await apiClient.getTopSongs(limit);
        const songs = Array.isArray(response.data) ? response.data : [];
        
        return songs.map((song: any) => ({
          id: song?.id ?? '',
          title: song?.title ?? '',
          duration: song?.duration ?? 0,
          fileUrl: song?.fileUrl ?? song?.file_url ?? '',
          coverImageUrl: song?.coverImageUrl ?? song?.cover_image_url ?? undefined,
          artistId: song?.artistId ?? song?.artist_id ?? undefined,
          artist: song?.artist ? {
            id: song.artist.id ?? '',
            stageName: song.artist.stageName ?? song.artist.stage_name ?? song.artist.name ?? undefined,
          } : undefined,
          totalStreams: song?.totalStreams ?? song?.total_streams ?? 0,
          totalLikes: song?.totalLikes ?? song?.total_likes ?? 0,
          createdAt: song?.createdAt ?? song?.created_at ?? new Date().toISOString(),
          updatedAt: song?.updatedAt ?? song?.updated_at ?? new Date().toISOString(),
        }));
      } catch (error) {
        console.error('Error fetching top songs:', error);
        throw error;
      }
    },
    {
      enabled,
      staleTime: 60000, // Los datos son válidos por 1 minuto
      refetchInterval: 120000, // Refrescar cada 2 minutos
      retry: 2,
      onError: (error) => {
        console.error('Error en useTopSongs:', extractErrorMessage(error));
        // No mostrar toast para no ser molesto
      },
    }
  );
};

