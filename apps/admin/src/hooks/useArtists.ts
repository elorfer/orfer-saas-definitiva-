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





