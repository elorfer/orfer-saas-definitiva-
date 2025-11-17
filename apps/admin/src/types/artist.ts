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
  user?: {
    id: string;
    email: string;
    username: string;
    firstName?: string;
    lastName?: string;
  };
}

export interface ArtistsResponse {
  artists: ArtistModel[];
  total: number;
}

export interface UseArtistsParams {
  page?: number;
  limit?: number;
  enabled?: boolean;
}





