import axios from 'axios';
import { useQuery } from 'react-query';
import { toast } from 'react-hot-toast';

import { apiClient } from '@/lib/api';
import { ArtistsResponse, ArtistModel, UseArtistsParams } from '@/types/artist';

const ARTISTS_QUERY_KEY = 'artists';

const mapArtist = (artist: any): ArtistModel => ({
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
  user: artist?.user ? {
    id: artist.user.id ?? '',
    email: artist.user.email ?? '',
    username: artist.user.username ?? '',
    firstName: artist.user.firstName ?? artist.user.first_name ?? undefined,
    lastName: artist.user.lastName ?? artist.user.last_name ?? undefined,
  } : undefined,
});

const mapArtistsResponse = (data: any): ArtistsResponse => ({
  artists: Array.isArray(data?.artists) ? data.artists.map(mapArtist) : [],
  total: Number(data?.total ?? data?.artists?.length ?? 0),
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

export const useArtists = ({ page = 1, limit = 100, enabled = true }: UseArtistsParams = {}) => {
  return useQuery<ArtistsResponse, Error>(
    [ARTISTS_QUERY_KEY, page, limit],
    async () => {
      const response = await apiClient.getArtists(page, limit);
      return mapArtistsResponse(response.data);
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

/**
 * Hook para obtener TODOS los artistas disponibles sin límite de paginación
 * Hace múltiples requests si es necesario para obtener todos los artistas
 */
export const useAllArtists = (enabled = true) => {
  return useQuery<ArtistsResponse, Error>(
    [ARTISTS_QUERY_KEY, 'all'],
    async () => {
      const allArtists: ArtistModel[] = [];
      let currentPage = 1;
      const pageSize = 100; // Tamaño de página razonable
      let hasMore = true;
      let total = 0;

      // Obtener todos los artistas haciendo múltiples requests
      while (hasMore) {
        try {
          const response = await apiClient.getArtists(currentPage, pageSize);
          const mappedResponse = mapArtistsResponse(response.data);
          
          allArtists.push(...mappedResponse.artists);
          total = mappedResponse.total;

          // Si obtuvimos menos artistas que el límite, no hay más páginas
          if (mappedResponse.artists.length < pageSize) {
            hasMore = false;
          } else {
            // Si ya tenemos todos los artistas según el total, no hay más páginas
            if (allArtists.length >= total) {
              hasMore = false;
            } else {
              currentPage++;
            }
          }
        } catch (error) {
          // Si hay un error, detener la búsqueda
          hasMore = false;
          throw error;
        }
      }

      return {
        artists: allArtists,
        total,
      };
    },
    {
      enabled,
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
      // Cache por 5 minutos ya que obtener todos los artistas puede ser costoso
      staleTime: 5 * 60 * 1000,
    }
  );
};





