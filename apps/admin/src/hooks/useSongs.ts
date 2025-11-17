import axios from 'axios';
import { useMutation, useQuery, useQueryClient } from 'react-query';
import { toast } from 'react-hot-toast';

import { apiClient } from '@/lib/api';
import { SongsResponse, SongModel, UseSongsParams, UploadSongInput } from '@/types/song';

const SONGS_QUERY_KEY = 'songs';

const mapArtist = (artist: any) => ({
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

const mapSong = (song: any): SongModel => {
  const duration = song?.duration ?? 0;
  const durationNumber = typeof duration === 'string' ? parseInt(duration, 10) : Number(duration);
  
  // Mapear portada - intentar múltiples campos posibles
  const coverImageUrl = song?.coverImageUrl ?? song?.coverArtUrl ?? song?.cover_image_url ?? song?.cover_art_url ?? undefined;
  
  // Log temporal para debug cuando hay problemas
  if (typeof window !== 'undefined' && process.env.NODE_ENV === 'development') {
    if (!coverImageUrl || durationNumber === 0) {
      console.log('🔍 Mapeando canción (con datos faltantes):', {
        id: song?.id,
        title: song?.title,
        duration_raw: song?.duration,
        duration_mapped: durationNumber,
        coverImageUrl_raw: song?.coverImageUrl,
        coverArtUrl_raw: song?.coverArtUrl,
        cover_image_url_raw: song?.cover_image_url,
        cover_art_url_raw: song?.cover_art_url,
        coverImageUrl_final: coverImageUrl,
        song_keys: Object.keys(song || {}),
      });
    }
  }
  
  return {
    id: song?.id ?? '',
    title: song?.title ?? '',
    duration: isNaN(durationNumber) ? 0 : durationNumber,
    fileUrl: song?.fileUrl ?? song?.file_url ?? '',
    coverImageUrl,
    artistId: song?.artistId ?? song?.artist_id ?? undefined,
    artist: song?.artist ? mapArtist(song.artist) : undefined,
    albumId: song?.albumId ?? song?.album_id ?? undefined,
    genreId: song?.genreId ?? song?.genre_id ?? undefined,
    status: song?.status ?? 'draft',
    totalStreams: song?.totalStreams ?? song?.total_streams ?? 0,
    totalLikes: song?.totalLikes ?? song?.total_likes ?? 0,
    createdAt: song?.createdAt ?? song?.created_at ?? new Date().toISOString(),
    updatedAt: song?.updatedAt ?? song?.updated_at ?? new Date().toISOString(),
  };
};

const mapSongsResponse = (data: any): SongsResponse => ({
  songs: Array.isArray(data?.songs) ? data.songs.map(mapSong) : [],
  total: Number(data?.total ?? data?.songs?.length ?? 0),
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

export const useSongs = ({ page = 1, limit = 10, enabled = true }: UseSongsParams = {}) => {
  return useQuery<SongsResponse, Error>(
    [SONGS_QUERY_KEY, page, limit],
    async () => {
      const response = await apiClient.getSongs(page, limit);
      return mapSongsResponse(response.data);
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

export const useUploadSong = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async ({ 
      audioFile, 
      coverFile, 
      songData,
      onProgress
    }: { 
      audioFile: File; 
      coverFile?: File;
      songData: {
        title: string;
        artistId: string;
        albumId?: string;
        genreId?: string;
        status?: string;
        duration?: number;
      };
      onProgress?: (progress: number) => void;
    }) => {
      const response = await apiClient.uploadSong(
        audioFile, 
        coverFile, 
        songData,
        (progressEvent) => {
          if (onProgress) {
            const percentCompleted = Math.round((progressEvent.loaded * 100) / progressEvent.total);
            onProgress(percentCompleted);
          }
        }
      );
      return response.data;
    },
    {
      onSuccess: async () => {
        // Invalidar todas las queries relacionadas con canciones
        await queryClient.invalidateQueries([SONGS_QUERY_KEY]);
        
        // Polling inteligente: refrescar hasta que la canción esté completamente procesada
        // La notificación de éxito se muestra desde el componente cuando el progreso llega al 100%
        let attempts = 0;
        const maxAttempts = 20; // 20 intentos = 10 segundos máximo
        
        const pollUntilReady = async () => {
          attempts++;
          
          // Refrescar queries
          const result = await queryClient.refetchQueries([SONGS_QUERY_KEY]);
          
          // Si ya hemos intentado varias veces, dejar de intentar sin mostrar notificación
          // La notificación ya se mostró cuando el progreso llegó al 100%
          if (attempts >= maxAttempts) {
            return;
          }
          
          // Esperar 500ms antes del siguiente intento
          setTimeout(pollUntilReady, 500);
        };
        
        // Comenzar polling después de 2 segundos iniciales
        setTimeout(pollUntilReady, 2000);
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useCreateSong = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (data: any) => {
      const response = await apiClient.createSong(data);
      return response.data;
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries([SONGS_QUERY_KEY]);
        toast.success('Canción creada exitosamente');
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useDeleteSong = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (id: string) => {
      await apiClient.deleteSong(id);
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries([SONGS_QUERY_KEY]);
        toast.success('Canción eliminada exitosamente');
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

