export interface ArtistModel {
  id: string;
  userId?: string;
  stageName?: string;
  bio?: string;
  websiteUrl?: string;
  socialLinks?: any;
  totalFollowers?: number;
  totalStreams?: number;
  monthlyListeners?: number;
  verificationStatus?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface SongModel {
  id: string;
  title: string;
  duration: number;
  fileUrl: string;
  coverImageUrl?: string;
  artistId?: string;
  artist?: ArtistModel;
  albumId?: string;
  genreId?: string;
  genres?: string[]; // Array de géneros musicales
  status: 'draft' | 'published' | 'archived';
  totalStreams: number;
  totalLikes: number;
  createdAt: string;
  updatedAt: string;
}

export interface SongsResponse {
  songs: SongModel[];
  total: number;
}

export interface UseSongsParams {
  page?: number;
  limit?: number;
  enabled?: boolean;
}

export interface UploadSongInput {
  file: File;
  title: string;
  artistId: string;
  albumId?: string;
  genreId?: string;
}

