export interface PlaylistModel {
  id: string;
  name: string;
  description?: string;
  coverArtUrl?: string;
  userId: string;
  isFeatured: boolean;
  totalTracks: number;
  totalDuration: number;
  totalFollowers: number;
  createdAt: string;
  updatedAt: string;
  user?: {
    id: string;
    email: string;
    name?: string;
  };
  playlistSongs?: Array<{
    id: string;
    position: number;
    song: {
      id: string;
      title: string;
      duration: number;
      coverImageUrl?: string;
      artist?: {
        id: string;
        stageName?: string;
      };
    };
  }>;
}

export interface PlaylistsResponse {
  playlists: PlaylistModel[];
  total: number;
}

export interface CreatePlaylistInput {
  name: string;
  description?: string;
  coverArtUrl?: string;
  songIds?: string[];
  isFeatured?: boolean;
}

export interface UpdatePlaylistInput {
  name?: string;
  description?: string;
  coverArtUrl?: string;
  songIds?: string[];
  isFeatured?: boolean;
}

export interface UsePlaylistsParams {
  page?: number;
  limit?: number;
  enabled?: boolean;
}

