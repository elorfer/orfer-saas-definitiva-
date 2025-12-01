import axios from 'axios';
import { useMutation, useQuery, useQueryClient } from 'react-query';
import { toast } from 'react-hot-toast';

import { apiClient } from '@/lib/api';
import { PlaylistsResponse, PlaylistModel, CreatePlaylistInput, UpdatePlaylistInput, UsePlaylistsParams } from '@/types/playlist';

const PLAYLISTS_QUERY_KEY = 'playlists';

const mapPlaylist = (playlist: any): PlaylistModel => {
  return {
    id: playlist?.id ?? '',
    name: playlist?.name ?? '',
    description: playlist?.description ?? undefined,
    coverArtUrl: playlist?.coverArtUrl ?? playlist?.cover_art_url ?? undefined,
    userId: playlist?.userId ?? playlist?.user_id ?? '',
    isFeatured: playlist?.isFeatured ?? playlist?.is_featured ?? false,
    totalTracks: playlist?.totalTracks ?? playlist?.total_tracks ?? 0,
    totalDuration: playlist?.totalDuration ?? playlist?.total_duration ?? 0,
    totalFollowers: playlist?.totalFollowers ?? playlist?.total_followers ?? 0,
    createdAt: playlist?.createdAt ?? playlist?.created_at ?? new Date().toISOString(),
    updatedAt: playlist?.updatedAt ?? playlist?.updated_at ?? new Date().toISOString(),
    user: playlist?.user ? {
      id: playlist.user.id ?? '',
      email: playlist.user.email ?? '',
      name: playlist.user.name ?? playlist.user.fullName ?? undefined,
    } : undefined,
    playlistSongs: Array.isArray(playlist?.playlistSongs) 
      ? playlist.playlistSongs.map((ps: any) => ({
          id: ps?.id ?? '',
          position: ps?.position ?? 0,
          song: {
            id: ps?.song?.id ?? '',
            title: ps?.song?.title ?? '',
            duration: ps?.song?.duration ?? 0,
            coverImageUrl: ps?.song?.coverImageUrl ?? ps?.song?.cover_image_url ?? undefined,
            artist: ps?.song?.artist ? {
              id: ps.song.artist.id ?? '',
              stageName: ps.song.artist.stageName ?? ps.song.artist.stage_name ?? undefined,
            } : undefined,
          },
        }))
      : undefined,
  };
};

const mapPlaylistsResponse = (data: any): PlaylistsResponse => ({
  playlists: Array.isArray(data?.playlists) ? data.playlists.map(mapPlaylist) : [],
  total: Number(data?.total ?? data?.playlists?.length ?? 0),
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

export const usePlaylists = ({ page = 1, limit = 10, enabled = true }: UsePlaylistsParams = {}) => {
  return useQuery<PlaylistsResponse, Error>(
    [PLAYLISTS_QUERY_KEY, page, limit],
    async () => {
      const response = await apiClient.getPlaylists(page, limit);
      return mapPlaylistsResponse(response.data);
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

export const useFeaturedPlaylists = (limit: number = 10) => {
  return useQuery<PlaylistModel[], Error>(
    ['playlists', 'featured', limit],
    async () => {
      const response = await apiClient.getFeaturedPlaylists(limit);
      return Array.isArray(response.data) ? response.data.map(mapPlaylist) : [];
    },
    {
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const usePlaylist = (id: string | null, enabled: boolean = true) => {
  return useQuery<PlaylistModel, Error>(
    ['playlist', id],
    async () => {
      if (!id) throw new Error('ID requerido');
      const response = await apiClient.getPlaylist(id);
      return mapPlaylist(response.data);
    },
    {
      enabled: enabled && !!id,
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useCreatePlaylist = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (data: CreatePlaylistInput) => {
      const response = await apiClient.createPlaylist(data);
      return mapPlaylist(response.data);
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries([PLAYLISTS_QUERY_KEY]);
        toast.success('Playlist creada exitosamente');
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useUpdatePlaylist = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async ({ id, data }: { id: string; data: UpdatePlaylistInput }) => {
      const response = await apiClient.updatePlaylist(id, data);
      return mapPlaylist(response.data);
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries([PLAYLISTS_QUERY_KEY]);
        toast.success('Playlist actualizada exitosamente');
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useDeletePlaylist = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (id: string) => {
      await apiClient.deletePlaylist(id);
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries([PLAYLISTS_QUERY_KEY]);
        queryClient.invalidateQueries(['playlists', 'featured']);
        toast.success('Playlist eliminada exitosamente');
      },
      onError: (error) => {
        const errorMessage = extractErrorMessage(error);
        console.error('Error al eliminar playlist:', error);
        toast.error(errorMessage);
      },
    }
  );
};

export const useToggleFeaturedPlaylist = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (id: string) => {
      const response = await apiClient.toggleFeaturedPlaylist(id);
      return mapPlaylist(response.data);
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries([PLAYLISTS_QUERY_KEY]);
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

export const useUploadPlaylistCover = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async ({ id, file }: { id: string; file: File }) => {
      const response = await apiClient.uploadPlaylistCover(id, file);
      return mapPlaylist(response.data);
    },
    {
      onSuccess: () => {
        queryClient.invalidateQueries([PLAYLISTS_QUERY_KEY]);
        toast.success('Portada actualizada exitosamente');
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

