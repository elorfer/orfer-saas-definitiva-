'use client';

import { useState } from 'react';
import {
  UsersIcon,
  MusicalNoteIcon,
  StarIcon,
  ArrowPathIcon,
  ListBulletIcon,
} from '@heroicons/react/24/outline';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';

const TABS = [
  { id: 'songs', label: 'Canciones Destacadas', icon: MusicalNoteIcon },
  { id: 'artists', label: 'Artistas Destacados', icon: UsersIcon },
  { id: 'playlists', label: 'Playlists Destacadas', icon: ListBulletIcon },
];

const resolveImageUrl = (url: string | undefined | null, type: 'cover' | 'profile' = 'cover') => {
  if (!url) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;

  const baseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';

  if (url.startsWith('/')) return `${baseUrl}${url}`;

  // Si no tiene slash, asumimos que es un nombre de archivo en la carpeta correspondiente
  if (type === 'cover') return `${baseUrl}/uploads/covers/${url}`;
  if (type === 'profile') return `${baseUrl}/uploads/profiles/${url}`;

  return `${baseUrl}/${url}`;
};

export default function FeaturedPage() {
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState<'songs' | 'artists' | 'playlists'>('songs');

  // Queries para obtener contenido destacado
  const { data: featuredSongs, isLoading: songsLoading, refetch: refetchSongs } = useQuery(
    ['featured', 'songs'],
    () => apiClient.getFeaturedSongs(100).then(res => res.data),
    { enabled: activeTab === 'songs' }
  );

  const { data: featuredArtists, isLoading: artistsLoading, refetch: refetchArtists } = useQuery(
    ['featured', 'artists'],
    () => apiClient.getFeaturedArtists(100).then(res => res.data),
    { enabled: activeTab === 'artists' }
  );

  const { data: featuredPlaylists, isLoading: playlistsLoading, refetch: refetchPlaylists } = useQuery(
    ['featured', 'playlists'],
    () => apiClient.getFeaturedPlaylists(100).then(res => res.data),
    { enabled: activeTab === 'playlists' }
  );

  // Queries para obtener TODO el contenido (para poder destacar/desdestacar)
  const { data: allSongs, isLoading: songsAllLoading, error: songsError } = useQuery(
    ['songs', 'all'],
    async () => {
      const response = await apiClient.getSongs(1, 1000, true);
      return response.data;
    },
    {
      enabled: activeTab === 'songs',
      onError: () => toast.error('Error al cargar canciones')
    }
  );

  const { data: allPlaylists, isLoading: playlistsAllLoading, error: playlistsError } = useQuery(
    ['playlists', 'all'],
    async () => {
      const response = await apiClient.getPlaylists(1, 1000);
      return response.data;
    },
    {
      enabled: activeTab === 'playlists',
      onError: () => toast.error('Error al cargar playlists')
    }
  );

  const playlists = allPlaylists?.playlists || [];
  const songs = allSongs?.songs || [];

  // Mutations para destacar/quitar destacado
  const featureSong = useMutation(
    (id: string) => apiClient.featureSong(id),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['featured', 'songs']);
        queryClient.invalidateQueries(['songs', 'all']);
        toast.success('Canción destacada exitosamente');
      },
      onError: (error: any) => {
        const errorMessage = error?.response?.data?.message || 'Error al destacar canción';
        toast.error(errorMessage);
      },
    }
  );

  const unfeatureSong = useMutation(
    (id: string) => apiClient.unfeatureSong(id),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['featured', 'songs']);
        queryClient.invalidateQueries(['songs', 'all']);
        toast.success('Canción ya no está destacada');
      },
      onError: (error: any) => {
        const errorMessage = error?.response?.data?.message || 'Error al quitar destacado';
        toast.error(errorMessage);
      },
    }
  );

  const featurePlaylist = useMutation(
    (id: string) => apiClient.featurePlaylist(id),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['featured', 'playlists']);
        queryClient.invalidateQueries(['playlists', 'all']);
        toast.success('Playlist destacada exitosamente');
      },
      onError: () => toast.error('Error al destacar playlist'),
    }
  );

  const unfeaturePlaylist = useMutation(
    (id: string) => apiClient.unfeaturePlaylist(id),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['featured', 'playlists']);
        queryClient.invalidateQueries(['playlists', 'all']);
        toast.success('Playlist ya no está destacada');
      },
      onError: () => toast.error('Error al quitar destacado'),
    }
  );

  const isLoading = songsLoading || artistsLoading || playlistsLoading || songsAllLoading || playlistsAllLoading;

  const featuredSongsIds = new Set(featuredSongs?.map((s: any) => s.id) || []);
  const featuredPlaylistsIds = new Set(featuredPlaylists?.map((p: any) => p.id) || []);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Contenido Destacado</h1>
          <p className="mt-1 text-sm text-gray-500">
            Gestiona qué canciones, artistas y playlists aparecen destacados en el inicio.
          </p>
        </div>
        <button
          onClick={() => {
            if (activeTab === 'songs') refetchSongs();
            if (activeTab === 'artists') refetchArtists();
            if (activeTab === 'playlists') refetchPlaylists();
          }}
          className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-brown-600 hover:text-brown-700"
        >
          <ArrowPathIcon className="h-4 w-4" />
          Actualizar
        </button>
      </div>

      <div className="bg-white border border-gray-200 rounded-2xl shadow-sm p-6">
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8">
            {TABS.map((tab) => {
              const Icon = tab.icon;
              const isActive = activeTab === tab.id;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id as any)}
                  className={`flex items-center gap-2 py-4 px-1 border-b-2 font-medium text-sm transition ${isActive
                      ? 'border-brown-700 text-brown-700'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                    }`}
                >
                  <Icon className="h-5 w-5" />
                  {tab.label}
                </button>
              );
            })}
          </nav>
        </div>

        <div className="mt-6">
          {isLoading ? (
            <div className="text-center py-12 text-sm text-gray-500">
              <div className="flex justify-center mb-2">
                <ArrowPathIcon className="h-6 w-6 animate-spin text-gray-400" />
              </div>
              Cargando contenido...
            </div>
          ) : activeTab === 'songs' ? (
            <SongsSection
              allSongs={songs}
              featuredSongsIds={featuredSongsIds}
              onFeature={featureSong.mutate}
              onUnfeature={unfeatureSong.mutate}
            />
          ) : activeTab === 'artists' ? (
            <ArtistsReadOnlySection
              featuredArtists={featuredArtists || []}
            />
          ) : (
            <PlaylistsSection
              allPlaylists={playlists}
              featuredPlaylistsIds={featuredPlaylistsIds}
              onFeature={featurePlaylist.mutate}
              onUnfeature={unfeaturePlaylist.mutate}
            />
          )}
        </div>
      </div>
    </div>
  );
}

function ImageWithFallback({ src, alt, className, fallbackIcon: FallbackIcon }: any) {
  const [error, setError] = useState(false);

  if (!src || error) {
    return (
      <div className={`flex items-center justify-center bg-gray-100 text-gray-400 ${className}`}>
        <FallbackIcon className="h-1/2 w-1/2" />
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={alt}
      className={className}
      onError={() => setError(true)}
    />
  );
}

function SongsSection({ allSongs, featuredSongsIds, onFeature, onUnfeature }: any) {
  if (!allSongs?.length) {
    return (
      <div className="text-center py-12 text-gray-500 text-sm">
        No hay canciones disponibles para destacar.
      </div>
    );
  }

  // Ordenar: Destacadas arriba
  const sortedSongs = [...allSongs].sort((a, b) => {
    const aFeatured = featuredSongsIds.has(a.id);
    const bFeatured = featuredSongsIds.has(b.id);
    return (bFeatured ? 1 : 0) - (aFeatured ? 1 : 0);
  });

  return (
    <div className="space-y-4">
      <div className="flex justify-between text-sm text-gray-500 mb-2">
        <span>Total: {allSongs.length}</span>
        <span className="text-yellow-600 font-medium">Destacadas: {featuredSongsIds.size}</span>
      </div>
      <div className="grid gap-3">
        {sortedSongs.map((song: any) => {
          const isFeatured = featuredSongsIds.has(song.id);
          const coverUrl = resolveImageUrl(song.coverArtUrl || song.coverImageUrl, 'cover');

          return (
            <div
              key={song.id}
              className={`flex items-center justify-between p-3 border rounded-lg transition ${isFeatured ? 'border-yellow-300 bg-yellow-50' : 'border-gray-100 hover:bg-gray-50'
                }`}
            >
              <div className="flex items-center gap-3 flex-1 min-w-0">
                <ImageWithFallback
                  src={coverUrl}
                  alt={song.title}
                  className="h-12 w-12 rounded-lg object-cover bg-gray-200"
                  fallbackIcon={MusicalNoteIcon}
                />

                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-semibold text-gray-900 truncate">{song.title}</p>
                    {isFeatured && <StarIcon className="h-3 w-3 text-yellow-500 flex-shrink-0" />}
                  </div>
                  <p className="text-xs text-gray-500 truncate">
                    {song.artist?.stageName || song.artist?.user?.email || 'Desconocido'}
                  </p>
                </div>
              </div>
              <button
                onClick={() => (isFeatured ? onUnfeature(song.id) : onFeature(song.id))}
                className={`ml-4 px-3 py-1.5 rounded-lg text-xs font-semibold transition flex items-center gap-1 ${isFeatured
                    ? 'bg-white text-yellow-700 border border-yellow-200 hover:bg-yellow-100'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                  }`}
              >
                {isFeatured ? 'Destacada' : 'Destacar'}
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function ArtistsReadOnlySection({ featuredArtists }: any) {
  if (!featuredArtists?.length) {
    return (
      <div className="text-center py-12 text-gray-500 text-sm">
        No hay artistas marcados como destacados desde la sección de Artistas.
      </div>
    );
  }

  return (
    <div className="grid gap-3">
      {featuredArtists.map((artist: any) => {
        const profileUrl = resolveImageUrl(artist.profilePhotoUrl, 'profile');

        return (
          <div
            key={artist.id}
            className="flex items-center justify-between p-3 border border-yellow-200 bg-yellow-50 rounded-lg"
          >
            <div className="flex items-center gap-3 flex-1 min-w-0">
              <ImageWithFallback
                src={profileUrl}
                alt={artist.stageName}
                className="h-12 w-12 rounded-full object-cover bg-gray-200"
                fallbackIcon={UsersIcon}
              />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-gray-900 truncate">
                  {artist.stageName || 'Sin nombre'}
                </p>
                <p className="text-xs text-gray-500">
                  {artist.totalFollowers || 0} seguidores
                </p>
              </div>
            </div>
            <span className="ml-4 px-2 py-1 rounded text-xs font-medium bg-yellow-100 text-yellow-800">
              Destacado
            </span>
          </div>
        );
      })}
    </div>
  );
}

function PlaylistsSection({ allPlaylists, featuredPlaylistsIds, onFeature, onUnfeature }: any) {
  if (!allPlaylists?.length) {
    return (
      <div className="text-center py-12 text-gray-500 text-sm">
        No hay playlists disponibles.
      </div>
    );
  }

  const sortedPlaylists = [...allPlaylists].sort((a, b) => {
    const aFeatured = featuredPlaylistsIds.has(a.id);
    const bFeatured = featuredPlaylistsIds.has(b.id);
    return (bFeatured ? 1 : 0) - (aFeatured ? 1 : 0);
  });

  return (
    <div className="grid gap-3">
      {sortedPlaylists.map((playlist: any) => {
        const isFeatured = featuredPlaylistsIds.has(playlist.id);
        const coverUrl = resolveImageUrl(playlist.coverArtUrl, 'cover');

        return (
          <div
            key={playlist.id}
            className={`flex items-center justify-between p-3 border rounded-lg transition ${isFeatured ? 'border-yellow-300 bg-yellow-50' : 'border-gray-100 hover:bg-gray-50'
              }`}
          >
            <div className="flex items-center gap-3 flex-1 min-w-0">
              <ImageWithFallback
                src={coverUrl}
                alt={playlist.name}
                className="h-12 w-12 rounded-lg object-cover bg-gray-200"
                fallbackIcon={ListBulletIcon}
              />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-gray-900 truncate">{playlist.name}</p>
                <p className="text-xs text-gray-500">
                  {playlist.totalTracks || 0} canciones
                </p>
              </div>
            </div>
            <button
              onClick={() => (isFeatured ? onUnfeature(playlist.id) : onFeature(playlist.id))}
              className={`ml-4 px-3 py-1.5 rounded-lg text-xs font-semibold transition ${isFeatured
                  ? 'bg-white text-yellow-700 border border-yellow-200 hover:bg-yellow-100'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
            >
              {isFeatured ? 'Destacada' : 'Destacar'}
            </button>
          </div>
        );
      })}
    </div>
  );
}
