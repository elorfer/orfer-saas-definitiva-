'use client';

import { useState } from 'react';
import {
  UsersIcon,
  MusicalNoteIcon,
  StarIcon,
  ArrowPathIcon,
} from '@heroicons/react/24/outline';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';

const TABS = [
  { id: 'songs', label: 'Canciones Destacadas', icon: MusicalNoteIcon },
  { id: 'artists', label: 'Artistas Destacados', icon: UsersIcon }, // Solo lectura (desde sección Artistas)
  { id: 'playlists', label: 'Playlists Destacadas', icon: MusicalNoteIcon },
];

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
      console.log('📊 Respuesta de canciones:', response.data);
      return response.data;
    },
    { 
      enabled: activeTab === 'songs',
      onError: (error: any) => {
        console.error('❌ Error al cargar canciones:', error);
        toast.error('Error al cargar canciones');
      }
    }
  );

  // Nota: Eliminado listado completo de artistas aquí para evitar gestión duplicada de destacados

  const { data: allPlaylists, isLoading: playlistsAllLoading, error: playlistsError } = useQuery(
    ['playlists', 'all'],
    async () => {
      const response = await apiClient.getPlaylists(1, 1000);
      console.log('📊 Respuesta de playlists:', response.data);
      return response.data;
    },
    { 
      enabled: activeTab === 'playlists',
      onError: (error: any) => {
        console.error('❌ Error al cargar playlists:', error);
        toast.error('Error al cargar playlists');
      }
    }
  );

  const playlists = allPlaylists?.playlists || [];
  // En artistas, solo se muestra la lista de destacados proveniente del backend
  const songs = allSongs?.songs || [];

  // Debug logs
  if (typeof window !== 'undefined' && process.env.NODE_ENV === 'development') {
    console.log('🎵 Canciones cargadas:', songs.length, songs);
    console.log('👤 Artistas destacados (solo lectura):', featuredArtists?.length || 0, featuredArtists);
    console.log('📋 Playlists cargadas:', playlists.length, playlists);
    console.log('📊 allSongs completo:', allSongs);
    console.log('📊 allPlaylists completo:', allPlaylists);
  }

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
        const errorMessage = error?.response?.data?.message || error?.message || 'Error al destacar canción';
        console.error('Error al destacar canción:', error);
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
        const errorMessage = error?.response?.data?.message || error?.message || 'Error al quitar destacado';
        console.error('Error al quitar destacado:', error);
        toast.error(errorMessage);
      },
    }
  );

  // Eliminadas mutations de destacar/desdestacar artistas desde este módulo (gestión se hace en /artists)

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
  // No se necesitan IDs destacados de artistas aquí
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
          className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-purple-400 hover:text-purple-600"
        >
          <ArrowPathIcon className="h-4 w-4" />
          Actualizar
        </button>
      </div>
          {/* Tabs */}
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
                      className={`flex items-center gap-2 py-4 px-1 border-b-2 font-medium text-sm transition ${
                        isActive
                          ? 'border-purple-500 text-purple-600'
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

            {/* Content */}
            <div className="mt-6">
              {isLoading ? (
                <div className="text-center py-12 text-sm text-gray-500">
                  Cargando...
                </div>
              ) : activeTab === 'songs' && songsError ? (
                <div className="text-center py-12">
                  <p className="text-sm text-red-600 mb-2">Error al cargar canciones</p>
                  <p className="text-xs text-gray-500">{songsError?.message || 'Error desconocido'}</p>
                </div>
              ) : activeTab === 'playlists' && playlistsError ? (
                <div className="text-center py-12">
                  <p className="text-sm text-red-600 mb-2">Error al cargar playlists</p>
                  <p className="text-xs text-gray-500">{playlistsError?.message || 'Error desconocido'}</p>
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

function SongsSection({ allSongs, featuredSongsIds, onFeature, onUnfeature }: any) {
  if (!allSongs || allSongs.length === 0) {
    return (
      <div className="text-center py-12">
        <p className="text-sm text-gray-500">No hay canciones disponibles</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="mb-4 flex items-center justify-between">
        <p className="text-sm text-gray-600">
          Total: <span className="font-semibold">{allSongs.length}</span> canciones
        </p>
        <p className="text-sm text-gray-600">
          Destacadas: <span className="font-semibold text-yellow-600">{featuredSongsIds.size}</span>
        </p>
      </div>
      <div className="grid gap-4">
        {allSongs.map((song: any) => {
          const isFeatured = featuredSongsIds.has(song.id);
          return (
            <div
              key={song.id}
              className={`flex items-center justify-between p-4 border rounded-lg hover:bg-gray-50 transition ${
                isFeatured ? 'border-yellow-300 bg-yellow-50' : 'border-gray-200'
              }`}
            >
              <div className="flex items-center gap-4 flex-1 min-w-0">
                {song.coverArtUrl || song.coverImageUrl ? (
                  <img
                    src={song.coverArtUrl || song.coverImageUrl}
                    alt={song.title}
                    className="h-12 w-12 rounded-lg object-cover"
                  />
                ) : (
                  <div className="h-12 w-12 rounded-lg bg-gradient-to-br from-purple-500 to-purple-600 flex items-center justify-center">
                    <MusicalNoteIcon className="h-6 w-6 text-white" />
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-medium text-gray-900 truncate">{song.title}</p>
                    {isFeatured && (
                      <StarIcon className="h-4 w-4 text-yellow-500 flex-shrink-0" />
                    )}
                  </div>
                  <p className="text-xs text-gray-500">
                    {song.artist?.stageName || song.artist?.user?.email || 'Sin artista'}
                  </p>
                </div>
              </div>
              <button
                onClick={() => (isFeatured ? onUnfeature(song.id) : onFeature(song.id))}
                className={`ml-4 px-4 py-2 rounded-lg text-sm font-medium transition flex items-center gap-1 ${
                  isFeatured
                    ? 'bg-yellow-100 text-yellow-800 hover:bg-yellow-200'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {isFeatured ? (
                  <>
                    <StarIcon className="h-4 w-4" />
                    Destacada
                  </>
                ) : (
                  <>
                    <StarIcon className="h-4 w-4" />
                    Destacar
                  </>
                )}
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function ArtistsReadOnlySection({ featuredArtists }: any) {
  if (!featuredArtists || featuredArtists.length === 0) {
    return (
      <div className="text-center py-12">
        <p className="text-sm text-gray-500">No hay artistas destacados</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="grid gap-4">
        {featuredArtists.map((artist: any) => {
          return (
            <div
              key={artist.id}
              className="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition"
            >
              <div className="flex items-center gap-4 flex-1 min-w-0">
                {artist.profilePhotoUrl ? (
                  <img
                    src={artist.profilePhotoUrl}
                    alt={artist.stageName || 'Artista'}
                    className="h-12 w-12 rounded-full object-cover"
                  />
                ) : (
                  <div className="h-12 w-12 rounded-full bg-gradient-to-br from-blue-500 to-blue-600 flex items-center justify-center text-white font-semibold">
                    {artist.stageName?.[0]?.toUpperCase() || 'A'}
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-900 truncate">
                    {artist.stageName || artist.user?.email || 'Sin nombre'}
                  </p>
                  <p className="text-xs text-gray-500">
                    {artist.totalFollowers || 0} seguidores
                  </p>
                </div>
              </div>
              <span className="ml-4 px-3 py-1 rounded-lg text-xs font-medium bg-yellow-50 text-yellow-700 border border-yellow-200">
                Destacado
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function PlaylistsSection({ allPlaylists, featuredPlaylistsIds, onFeature, onUnfeature }: any) {
  if (!allPlaylists || allPlaylists.length === 0) {
    return (
      <div className="text-center py-12">
        <p className="text-sm text-gray-500">No hay playlists disponibles</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="grid gap-4">
        {allPlaylists.map((playlist: any) => {
          const isFeatured = featuredPlaylistsIds.has(playlist.id);
          return (
            <div
              key={playlist.id}
              className="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition"
            >
              <div className="flex items-center gap-4 flex-1 min-w-0">
                {playlist.coverArtUrl ? (
                  <img
                    src={playlist.coverArtUrl}
                    alt={playlist.name}
                    className="h-12 w-12 rounded-lg object-cover"
                  />
                ) : (
                  <div className="h-12 w-12 rounded-lg bg-gradient-to-br from-green-500 to-green-600 flex items-center justify-center">
                    <MusicalNoteIcon className="h-6 w-6 text-white" />
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-900 truncate">{playlist.name}</p>
                  <p className="text-xs text-gray-500">
                    {playlist.totalTracks || 0} canciones • {playlist.user?.email || 'Usuario'}
                  </p>
                </div>
              </div>
              <button
                onClick={() => (isFeatured ? onUnfeature(playlist.id) : onFeature(playlist.id))}
                className={`ml-4 px-4 py-2 rounded-lg text-sm font-medium transition ${
                  isFeatured
                    ? 'bg-yellow-100 text-yellow-800 hover:bg-yellow-200'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {isFeatured ? (
                  <>
                    <StarIcon className="h-4 w-4 inline mr-1" />
                    Destacada
                  </>
                ) : (
                  'Destacar'
                )}
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}

