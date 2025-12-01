'use client';

import React, { useMemo, useState, useRef, useEffect } from 'react';
import { toast } from 'react-hot-toast';
import {
  ArrowPathIcon,
  MagnifyingGlassIcon,
  UsersIcon,
  MusicalNoteIcon,
  XMarkIcon,
  TrashIcon,
  PlusIcon,
  ClockIcon,
  StarIcon,
  ListBulletIcon,
  PhotoIcon,
  CheckIcon,
} from '@heroicons/react/24/outline';

import { usePlaylists, useCreatePlaylist, useUpdatePlaylist, useDeletePlaylist, useToggleFeaturedPlaylist, useUploadPlaylistCover, useFeaturedPlaylists, usePlaylist } from '@/hooks/usePlaylists';
import { useSongs } from '@/hooks/useSongs';
import { apiClient } from '@/lib/api';
import { useQueryClient } from 'react-query';
import type { PlaylistModel } from '@/types/playlist';
import type { SongModel } from '@/types/song';

const PAGE_SIZE = 10;
const DEFAULT_PLAYLIST_FORM = {
  name: '',
  description: '',
  coverFile: null as File | null,
  songIds: [] as string[],
  isFeatured: false,
};

const formatDurationShort = (seconds: number): string => {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs.toString().padStart(2, '0')}`;
};

// Componente para checkbox con estado indeterminado
function SelectAllCheckbox({ 
  checked, 
  indeterminate, 
  onChange 
}: { 
  checked: boolean; 
  indeterminate: boolean; 
  onChange: (checked: boolean) => void;
}) {
  const checkboxRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (checkboxRef.current) {
      checkboxRef.current.indeterminate = indeterminate;
    }
  }, [indeterminate]);

  return (
    <input
      ref={checkboxRef}
      type="checkbox"
      checked={checked}
      onChange={(e) => onChange(e.target.checked)}
      className="h-4 w-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500 cursor-pointer"
    />
  );
}

// Componente para la fila de playlist
function PlaylistRow({ 
  playlist, 
  onDelete, 
  onToggleFeatured,
  onViewDetails,
  isDeleting,
  isSelected,
  onSelect,
}: { 
  playlist: PlaylistModel; 
  onDelete: (playlist: PlaylistModel) => void;
  onToggleFeatured: (playlist: PlaylistModel) => void;
  onViewDetails: (playlist: PlaylistModel) => void;
  isDeleting: boolean;
  isSelected: boolean;
  onSelect: (playlistId: string, selected: boolean) => void;
}) {
  const [imageError, setImageError] = useState(false);
  
  const getCoverUrl = () => {
    if (!playlist.coverArtUrl) return null;
    
    if (playlist.coverArtUrl.startsWith('http://') || playlist.coverArtUrl.startsWith('https://')) {
      return playlist.coverArtUrl;
    }
    
    if (playlist.coverArtUrl.startsWith('/')) {
      const baseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';
      return `${baseUrl}${playlist.coverArtUrl}`;
    }
    
    const baseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';
    return `${baseUrl}/uploads/covers/${playlist.coverArtUrl}`;
  };
  
  const coverUrl = getCoverUrl();

  return (
    <tr 
      className={`hover:bg-gray-50 transition ${isSelected ? 'bg-blue-50' : ''}`}
    >
      <td className="py-4 px-4">
        <div className="flex items-center gap-3">
          <input
            type="checkbox"
            checked={isSelected}
            onChange={(e) => {
              e.stopPropagation();
              onSelect(playlist.id, e.target.checked);
            }}
            onClick={(e) => e.stopPropagation()}
            className="h-4 w-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500 cursor-pointer"
          />
          {coverUrl && !imageError ? (
            <div className="h-12 w-12 flex-shrink-0 rounded-lg overflow-hidden border border-gray-200 bg-gray-100 shadow-sm">
              <img
                src={coverUrl}
                alt={`Portada de ${playlist.name}`}
                className="h-full w-full object-cover"
                onError={() => setImageError(true)}
                loading="lazy"
              />
            </div>
          ) : (
            <div className="h-12 w-12 flex-shrink-0 rounded-lg bg-gradient-to-br from-purple-500 to-purple-600 text-white flex items-center justify-center shadow-sm">
              <ListBulletIcon className="h-5 w-5" />
            </div>
          )}
          <div 
            className="min-w-0 flex-1 cursor-pointer"
            onClick={() => onViewDetails(playlist)}
          >
            <p className="text-sm font-medium text-gray-900 truncate">{playlist.name}</p>
            <p className="text-xs text-gray-500">
              {new Date(playlist.createdAt).toLocaleDateString('es-ES')}
            </p>
          </div>
        </div>
      </td>
      <td className="py-4 px-4">
        <p className="text-sm text-gray-900 truncate max-w-xs">
          {playlist.description || 'Sin descripción'}
        </p>
      </td>
      <td className="py-4 px-4">
        <div className="flex items-center gap-4 text-xs text-gray-600">
          <div className="flex items-center gap-1">
            <MusicalNoteIcon className="h-3 w-3" />
            {playlist.totalTracks} canciones
          </div>
          <div className="flex items-center gap-1">
            <ClockIcon className="h-3 w-3" />
            {formatDurationShort(playlist.totalDuration)}
          </div>
        </div>
      </td>
      <td className="py-4 px-4">
        {playlist.isFeatured ? (
          <span className="inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold bg-yellow-100 text-yellow-700">
            <StarIcon className="h-3 w-3 mr-1" />
            Destacada
          </span>
        ) : (
          <span className="inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold bg-gray-100 text-gray-700">
            Normal
          </span>
        )}
      </td>
      <td className="py-4 px-4 text-right">
        <div className="flex items-center justify-end gap-2">
          <button
            onClick={(e) => {
              e.stopPropagation();
              onToggleFeatured(playlist);
            }}
            className={`inline-flex items-center rounded-lg px-3 py-1.5 text-xs font-semibold transition ${
              playlist.isFeatured
                ? 'bg-yellow-50 text-yellow-700 hover:bg-yellow-100'
                : 'bg-gray-50 text-gray-700 hover:bg-gray-100'
            }`}
            title={playlist.isFeatured ? 'Quitar destacado' : 'Destacar'}
          >
            <StarIcon className={`h-4 w-4 ${playlist.isFeatured ? 'fill-current' : ''}`} />
          </button>
          <button
            onClick={(e) => {
              e.stopPropagation();
              onDelete(playlist);
            }}
            className="inline-flex items-center rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-500 transition hover:border-red-300 hover:text-red-600 disabled:cursor-not-allowed disabled:opacity-60"
            disabled={isDeleting}
          >
            <TrashIcon className={`h-4 w-4 ${isDeleting ? 'animate-spin' : ''}`} />
            <span className="ml-1">Eliminar</span>
          </button>
        </div>
      </td>
    </tr>
  );
}

export default function PlaylistsPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [playlistForm, setPlaylistForm] = useState(DEFAULT_PLAYLIST_FORM);
  const [uploadingCover, setUploadingCover] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [selectedPlaylist, setSelectedPlaylist] = useState<PlaylistModel | null>(null);
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [selectedPlaylistIds, setSelectedPlaylistIds] = useState<Set<string>>(new Set());
  const [isDeletingMultiple, setIsDeletingMultiple] = useState(false);
  const notificationShownRef = useRef(false);

  const { data, isLoading } = usePlaylists({ page, limit: PAGE_SIZE, enabled: true });
  const playlists = data?.playlists ?? [];

  const { data: songsData } = useSongs({ page: 1, limit: 1000, enabled: true });
  const allSongs = songsData?.songs ?? [];

  const { data: featuredData } = useFeaturedPlaylists(10);
  const featuredPlaylists = featuredData ?? [];

  const { data: playlistDetails, isLoading: loadingDetails } = usePlaylist(
    selectedPlaylist?.id || '',
    showDetailsModal && !!selectedPlaylist
  );

  const queryClient = useQueryClient();
  const { mutateAsync: createPlaylist } = useCreatePlaylist();
  const { mutateAsync: updatePlaylist } = useUpdatePlaylist();
  const { mutateAsync: deletePlaylist } = useDeletePlaylist();
  const { mutateAsync: toggleFeatured } = useToggleFeaturedPlaylist();
  const { mutateAsync: uploadCover } = useUploadPlaylistCover();


  const openCreateModal = () => {
    setPlaylistForm(DEFAULT_PLAYLIST_FORM);
    setUploadProgress(0);
    setUploadingCover(false);
    notificationShownRef.current = false;
    setShowCreateModal(true);
  };

  const handleCoverFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];
      if (!allowedTypes.includes(file.type)) {
        alert('Tipo de archivo no permitido. Solo se permiten imágenes: .jpg, .jpeg, .png, .webp, .gif');
        return;
      }
      setPlaylistForm((prev) => ({ ...prev, coverFile: file }));
    }
  };

  const handleCreatePlaylist = async (event: React.FormEvent) => {
    event.preventDefault();

    if (!playlistForm.name.trim()) {
      alert('Por favor ingresa un título para la playlist');
      return;
    }

    try {
      setUploadingCover(true);
      setUploadProgress(0);

      // Crear la playlist primero (sin portada en el payload)
      const playlistData = {
        name: playlistForm.name,
        description: playlistForm.description || undefined,
        songIds: playlistForm.songIds,
        isFeatured: playlistForm.isFeatured,
      };

      const newPlaylist = await createPlaylist(playlistData);

      // Si hay portada, subirla después
      if (playlistForm.coverFile) {
        try {
          await uploadCover({
            id: newPlaylist.id,
            file: playlistForm.coverFile,
          });
        } catch (coverError) {
          // Si falla la subida de portada, pero la playlist se creó, continuar
          console.error('Error al subir portada:', coverError);
        }
      }

      setShowCreateModal(false);
      setPlaylistForm(DEFAULT_PLAYLIST_FORM);
      setUploadProgress(0);
    } catch (error) {
      // Error manejado por los hooks
      setUploadProgress(0);
    } finally {
      setUploadingCover(false);
    }
  };

  const handleDeletePlaylist = async (playlist: PlaylistModel) => {
    const confirmed = window.confirm(`¿Seguro que deseas eliminar "${playlist.name}"?`);
    if (!confirmed) return;

    try {
      setDeletingId(playlist.id);
      await deletePlaylist(playlist.id);
      // Remover de selección si estaba seleccionada
      setSelectedPlaylistIds((prev) => {
        const newSet = new Set(prev);
        newSet.delete(playlist.id);
        return newSet;
      });
    } finally {
      setDeletingId(null);
    }
  };

  const handleSelectPlaylist = (playlistId: string, selected: boolean) => {
    setSelectedPlaylistIds((prev) => {
      const newSet = new Set(prev);
      if (selected) {
        newSet.add(playlistId);
      } else {
        newSet.delete(playlistId);
      }
      return newSet;
    });
  };

  const handleSelectAll = (checked: boolean) => {
    if (checked) {
      const allIds = new Set(filteredPlaylists.map((p) => p.id));
      setSelectedPlaylistIds(allIds);
    } else {
      setSelectedPlaylistIds(new Set());
    }
  };

  const handleDeleteSelected = async () => {
    if (selectedPlaylistIds.size === 0) return;

    const count = selectedPlaylistIds.size;
    const confirmed = window.confirm(
      `¿Seguro que deseas eliminar ${count} ${count === 1 ? 'playlist' : 'playlists'}?`
    );
    if (!confirmed) return;

    try {
      setIsDeletingMultiple(true);
      const idsArray = Array.from(selectedPlaylistIds);
      
      // Eliminar todas las playlists seleccionadas directamente con la API
      // sin usar el hook para evitar notificaciones individuales
      await Promise.all(idsArray.map((id) => apiClient.deletePlaylist(id)));
      
      // Invalidar queries para refrescar la lista
      queryClient.invalidateQueries(['playlists']);
      queryClient.invalidateQueries(['playlists', 'featured']);
      
      // Limpiar selección
      setSelectedPlaylistIds(new Set());
      
      // Mostrar solo una notificación con el conteo total
      toast.success(`${count} ${count === 1 ? 'playlist eliminada' : 'playlists eliminadas'} exitosamente`);
    } catch (error) {
      console.error('Error al eliminar playlists:', error);
      toast.error('Error al eliminar algunas playlists');
    } finally {
      setIsDeletingMultiple(false);
    }
  };

  const handleToggleFeatured = async (playlist: PlaylistModel) => {
    try {
      await toggleFeatured(playlist.id);
    } catch (error) {
      // Error manejado por los hooks
    }
  };

  const handleViewDetails = (playlist: PlaylistModel) => {
    setSelectedPlaylist(playlist);
    setShowDetailsModal(true);
  };

  const closeDetailsModal = () => {
    setShowDetailsModal(false);
    setSelectedPlaylist(null);
  };

  const filteredPlaylists = useMemo(() => {
    if (!search.trim()) return playlists;
    const query = search.toLowerCase();

    return playlists.filter((playlist) => {
      return (
        playlist.name.toLowerCase().includes(query) ||
        playlist.description?.toLowerCase().includes(query)
      );
    });
  }, [playlists, search]);

  const allSelected = filteredPlaylists.length > 0 && filteredPlaylists.every((p) => selectedPlaylistIds.has(p.id));
  const someSelected = selectedPlaylistIds.size > 0 && !allSelected;

  const total = data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const handleNext = () => {
    if (page < totalPages) {
      setPage((prev) => prev + 1);
    }
  };

  const handlePrev = () => {
    if (page > 1) {
      setPage((prev) => prev - 1);
    }
  };

  const toggleSongSelection = (songId: string) => {
    setPlaylistForm((prev) => ({
      ...prev,
      songIds: prev.songIds.includes(songId)
        ? prev.songIds.filter((id) => id !== songId)
        : [...prev.songIds, songId],
    }));
  };

  return (
    <>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-4 flex-wrap gap-4">
            <div>
              <h1 className="text-2xl xl:text-3xl font-bold text-gray-900">Administrar Playlists</h1>
              <p className="text-sm text-gray-500 mt-1">Gestiona las playlists de la plataforma</p>
            </div>
            <button
              onClick={openCreateModal}
              className="inline-flex items-center gap-2 rounded-lg bg-purple-600 px-5 py-3 text-base font-semibold text-white shadow-md transition hover:bg-purple-700 hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2"
            >
              <PlusIcon className="h-6 w-6" />
              <span>Crear Playlist</span>
            </button>
          </div>

          {/* Featured Section */}
          {featuredPlaylists.length > 0 && (
            <div className="mb-6 p-4 bg-gradient-to-r from-yellow-50 to-yellow-100 rounded-xl border border-yellow-200">
              <div className="flex items-center gap-2 mb-3">
                <StarIcon className="h-5 w-5 text-yellow-600 fill-current" />
                <h2 className="text-lg font-semibold text-yellow-900">Playlists Destacadas</h2>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                {featuredPlaylists.slice(0, 4).map((playlist) => (
                  <div
                    key={playlist.id}
                    className="bg-white rounded-lg p-3 border border-yellow-200 shadow-sm hover:shadow-md transition"
                  >
                    <div className="flex items-center gap-2">
                      {playlist.coverArtUrl ? (
                        <img
                          src={playlist.coverArtUrl}
                          alt={playlist.name}
                          className="h-10 w-10 rounded object-cover"
                        />
                      ) : (
                        <div className="h-10 w-10 rounded bg-purple-100 flex items-center justify-center">
                          <ListBulletIcon className="h-5 w-5 text-purple-600" />
                        </div>
                      )}
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-gray-900 truncate">{playlist.name}</p>
                        <p className="text-xs text-gray-500">{playlist.totalTracks} canciones</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Search */}
          <div className="relative">
            <MagnifyingGlassIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
            <input
              type="text"
              placeholder="Buscar playlists..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg bg-white text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
            />
          </div>
        </div>

        {/* Stats y acciones de selección */}
        <div className="mb-6 flex items-center justify-between gap-4 flex-wrap">
          <p className="text-sm text-gray-500">{total.toLocaleString('es-ES')} playlists en total</p>
          {selectedPlaylistIds.size > 0 && (
            <div className="flex items-center gap-3">
              <span className="text-sm text-gray-600 font-medium">
                {selectedPlaylistIds.size} {selectedPlaylistIds.size === 1 ? 'playlist seleccionada' : 'playlists seleccionadas'}
              </span>
              <button
                onClick={handleDeleteSelected}
                disabled={isDeletingMultiple}
                className="inline-flex items-center gap-2 rounded-lg border border-red-300 bg-red-50 px-4 py-2 text-sm font-semibold text-red-700 transition hover:bg-red-100 disabled:cursor-not-allowed disabled:opacity-50"
              >
                {isDeletingMultiple ? (
                  <>
                    <ArrowPathIcon className="h-4 w-4 animate-spin" />
                    Eliminando...
                  </>
                ) : (
                  <>
                    <TrashIcon className="h-4 w-4" />
                    Eliminar seleccionadas
                  </>
                )}
              </button>
            </div>
          )}
        </div>

        {/* Playlists Table */}
        <div className="overflow-hidden rounded-xl border border-gray-200 bg-white">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 w-12">
                  <SelectAllCheckbox
                    checked={allSelected}
                    indeterminate={someSelected}
                    onChange={handleSelectAll}
                  />
                </th>
                <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                  Playlist
                </th>
                <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                  Descripción
                </th>
                <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                  Contenido
                </th>
                <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                  Estado
                </th>
                <th className="py-3 px-4 text-right text-xs font-semibold uppercase tracking-wider text-gray-500">
                  Acciones
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {isLoading ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-sm text-gray-500">
                    Cargando playlists...
                  </td>
                </tr>
              ) : filteredPlaylists.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-sm text-gray-500">
                    No se encontraron playlists.
                  </td>
                </tr>
              ) : (
                filteredPlaylists.map((playlist) => (
                  <PlaylistRow
                    key={playlist.id}
                    playlist={playlist}
                    onDelete={handleDeletePlaylist}
                    onToggleFeatured={handleToggleFeatured}
                    onViewDetails={handleViewDetails}
                    isDeleting={deletingId === playlist.id}
                    isSelected={selectedPlaylistIds.has(playlist.id)}
                    onSelect={handleSelectPlaylist}
                  />
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="mt-6 flex flex-col items-center justify-between gap-4 sm:flex-row">
          <p className="text-sm text-gray-500">
            Página {page} de {totalPages}
          </p>
          <div className="flex items-center gap-2">
            <button
              onClick={handlePrev}
              disabled={page === 1}
              className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-500 transition hover:border-purple-400 hover:text-purple-600 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Anterior
            </button>
            <button
              onClick={handleNext}
              disabled={page === totalPages}
              className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-500 transition hover:border-purple-400 hover:text-purple-600 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Siguiente
            </button>
          </div>
        </div>
      </div>

      {/* Create Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm px-4">
          <div className="w-full max-w-2xl max-h-[90vh] overflow-y-auto rounded-2xl bg-white shadow-xl">
            <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4 sticky top-0 bg-white z-10">
              <div>
                <h2 className="text-lg font-semibold text-gray-900">Crear nueva playlist</h2>
                <p className="text-sm text-gray-500">Completa la información de la playlist</p>
              </div>
              <button
                onClick={() => {
                  if (!uploadingCover) {
                    setShowCreateModal(false);
                    setPlaylistForm(DEFAULT_PLAYLIST_FORM);
                    setUploadProgress(0);
                  }
                }}
                className="rounded-full p-1 text-gray-400 transition hover:bg-gray-100 hover:text-gray-600 disabled:cursor-not-allowed disabled:opacity-50"
                aria-label="Cerrar"
                disabled={uploadingCover}
              >
                <XMarkIcon className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={handleCreatePlaylist} className="px-6 py-6 space-y-6">
              {/* Cover Upload */}
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Portada de la playlist (opcional)
                </label>
                <div className="mt-1">
                  {playlistForm.coverFile ? (
                    <div className="w-full border-2 border-blue-300 border-dashed rounded-lg bg-blue-50 p-4">
                      <div className="flex items-center gap-3">
                        <div className="flex-shrink-0">
                          <div className="h-20 w-20 rounded-lg bg-blue-100 flex items-center justify-center overflow-hidden">
                            <img
                              src={URL.createObjectURL(playlistForm.coverFile)}
                              alt="Vista previa"
                              className="h-full w-full object-cover"
                            />
                          </div>
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-semibold text-gray-900 truncate">
                            {playlistForm.coverFile.name}
                          </p>
                          <p className="text-xs text-gray-600">
                            {(playlistForm.coverFile.size / 1024 / 1024).toFixed(2)} MB • Imagen seleccionada
                          </p>
                        </div>
                        <button
                          type="button"
                          onClick={() => setPlaylistForm((prev) => ({ ...prev, coverFile: null }))}
                          className="flex-shrink-0 rounded-lg p-2 text-gray-400 hover:bg-red-50 hover:text-red-600 transition"
                          disabled={uploadingCover}
                        >
                          <XMarkIcon className="h-5 w-5" />
                        </button>
                      </div>
                    </div>
                  ) : (
                    <label className="flex flex-col items-center justify-center w-full h-32 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100 hover:border-blue-400 transition group">
                      <div className="flex flex-col items-center justify-center pt-5 pb-6">
                        <div className="h-12 w-12 rounded-lg bg-blue-100 flex items-center justify-center mb-3 group-hover:bg-blue-200 transition">
                          <PhotoIcon className="h-6 w-6 text-blue-600" />
                        </div>
                        <p className="mb-2 text-sm text-gray-600 group-hover:text-gray-900">
                          <span className="font-semibold">Click para seleccionar</span> o arrastra la imagen
                        </p>
                        <p className="text-xs text-gray-500">JPG, PNG, WEBP, GIF (máx. 10MB)</p>
                      </div>
                      <input
                        type="file"
                        accept="image/jpeg,image/jpg,image/png,image/webp,image/gif"
                        onChange={handleCoverFileChange}
                        className="hidden"
                        disabled={uploadingCover}
                      />
                    </label>
                  )}
                </div>
              </div>

              {/* Title */}
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Título de la playlist *
                </label>
                <input
                  type="text"
                  value={playlistForm.name}
                  onChange={(event) =>
                    setPlaylistForm((prev) => ({ ...prev, name: event.target.value }))
                  }
                  required
                  disabled={uploadingCover}
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100 disabled:bg-gray-50 disabled:cursor-not-allowed"
                  placeholder="Ej. Mis Canciones Favoritas"
                />
              </div>

              {/* Description */}
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Descripción (opcional)
                </label>
                <textarea
                  value={playlistForm.description}
                  onChange={(event) =>
                    setPlaylistForm((prev) => ({ ...prev, description: event.target.value }))
                  }
                  disabled={uploadingCover}
                  rows={3}
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100 disabled:bg-gray-50 disabled:cursor-not-allowed"
                  placeholder="Describe tu playlist..."
                />
              </div>

              {/* Featured Toggle */}
              <div className="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="isFeatured"
                  checked={playlistForm.isFeatured}
                  onChange={(event) =>
                    setPlaylistForm((prev) => ({ ...prev, isFeatured: event.target.checked }))
                  }
                  disabled={uploadingCover}
                  className="h-4 w-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500 disabled:cursor-not-allowed"
                />
                <label htmlFor="isFeatured" className="text-sm font-medium text-gray-700">
                  Marcar como destacada
                </label>
              </div>

              {/* Songs Selection */}
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2">
                  Seleccionar canciones ({playlistForm.songIds.length} seleccionadas)
                </label>
                <div className="border border-gray-200 rounded-lg max-h-60 overflow-y-auto">
                  {allSongs.length === 0 ? (
                    <p className="p-4 text-sm text-gray-500 text-center">No hay canciones disponibles</p>
                  ) : (
                    <div className="divide-y divide-gray-100">
                      {allSongs.map((song) => (
                        <label
                          key={song.id}
                          className="flex items-center gap-3 p-3 hover:bg-gray-50 cursor-pointer transition"
                        >
                          <input
                            type="checkbox"
                            checked={playlistForm.songIds.includes(song.id)}
                            onChange={() => toggleSongSelection(song.id)}
                            disabled={uploadingCover}
                            className="h-4 w-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500 disabled:cursor-not-allowed"
                          />
                          <div className="flex-1 min-w-0">
                            <p className="text-sm font-medium text-gray-900 truncate">{song.title}</p>
                            <p className="text-xs text-gray-500">
                              {song.artist?.stageName || song.artist?.user?.email || 'Sin artista'}
                            </p>
                          </div>
                        </label>
                      ))}
                    </div>
                  )}
                </div>
              </div>

              {/* Actions */}
              <div className="flex items-center justify-end gap-3 pt-2 border-t border-gray-200">
                <button
                  type="button"
                  onClick={() => {
                    if (!uploadingCover) {
                      setShowCreateModal(false);
                      setPlaylistForm(DEFAULT_PLAYLIST_FORM);
                      setUploadProgress(0);
                    }
                  }}
                  className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-gray-300 hover:text-gray-700 disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={uploadingCover}
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  disabled={uploadingCover || !playlistForm.name.trim()}
                  className="inline-flex items-center rounded-lg bg-purple-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-purple-700 disabled:cursor-not-allowed disabled:bg-purple-400"
                >
                  {uploadingCover ? (
                    <>
                      <ArrowPathIcon className="h-4 w-4 mr-2 animate-spin" />
                      Creando...
                    </>
                  ) : (
                    'Crear playlist'
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Details Modal */}
      {showDetailsModal && selectedPlaylist && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm px-4">
          <div className="w-full max-w-4xl max-h-[90vh] overflow-y-auto rounded-2xl bg-white shadow-xl">
            <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4 sticky top-0 bg-white z-10">
              <div>
                <h2 className="text-lg font-semibold text-gray-900">Detalles de Playlist</h2>
                <p className="text-sm text-gray-500">{selectedPlaylist.name}</p>
              </div>
              <button
                onClick={closeDetailsModal}
                className="rounded-full p-1 text-gray-400 transition hover:bg-gray-100 hover:text-gray-600"
                aria-label="Cerrar"
              >
                <XMarkIcon className="h-6 w-6" />
              </button>
            </div>

            <div className="p-6">
              {loadingDetails ? (
                <div className="flex items-center justify-center py-12">
                  <div className="text-center">
                    <div className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-purple-600 border-r-transparent"></div>
                    <p className="mt-2 text-sm text-gray-500">Cargando detalles...</p>
                  </div>
                </div>
              ) : playlistDetails ? (
                <div className="space-y-6">
                  {/* Cover and Basic Info */}
                  <div className="flex items-start gap-6">
                    {playlistDetails.coverArtUrl ? (
                      <img
                        src={playlistDetails.coverArtUrl.startsWith('http') 
                          ? playlistDetails.coverArtUrl 
                          : `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000'}${playlistDetails.coverArtUrl}`}
                        alt={playlistDetails.name}
                        className="h-32 w-32 rounded-lg object-cover border border-gray-200 shadow-sm"
                      />
                    ) : (
                      <div className="h-32 w-32 rounded-lg bg-gradient-to-br from-purple-500 to-purple-600 text-white flex items-center justify-center shadow-sm">
                        <ListBulletIcon className="h-12 w-12" />
                      </div>
                    )}
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-2">
                        <h3 className="text-2xl font-bold text-gray-900">{playlistDetails.name}</h3>
                        {playlistDetails.isFeatured && (
                          <span className="inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold bg-yellow-100 text-yellow-700">
                            <StarIcon className="h-3 w-3 mr-1 fill-current" />
                            Destacada
                          </span>
                        )}
                      </div>
                      {playlistDetails.description && (
                        <p className="text-sm text-gray-600 mb-4">{playlistDetails.description}</p>
                      )}
                      <div className="flex items-center gap-6 text-sm text-gray-600">
                        <div className="flex items-center gap-1">
                          <MusicalNoteIcon className="h-4 w-4" />
                          {playlistDetails.totalTracks} canciones
                        </div>
                        <div className="flex items-center gap-1">
                          <ClockIcon className="h-4 w-4" />
                          {formatDurationShort(playlistDetails.totalDuration)}
                        </div>
                        {playlistDetails.user && (
                          <div className="flex items-center gap-1">
                            <UsersIcon className="h-4 w-4" />
                            {playlistDetails.user.name || playlistDetails.user.email || 'Usuario'}
                          </div>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Songs List */}
                  <div>
                    <h4 className="text-lg font-semibold text-gray-900 mb-4">Canciones</h4>
                    {playlistDetails.playlistSongs && playlistDetails.playlistSongs.length > 0 ? (
                      <div className="space-y-2">
                        {playlistDetails.playlistSongs
                          .sort((a, b) => a.position - b.position)
                          .map((playlistSong, index) => {
                            const song = playlistSong.song;
                            if (!song) return null;
                            return (
                          <div
                            key={playlistSong.id}
                            className="flex items-center gap-4 p-3 rounded-lg border border-gray-200 hover:bg-gray-50 transition"
                          >
                            <div className="flex-shrink-0 w-8 text-center text-sm text-gray-500 font-medium">
                              {index + 1}
                            </div>
                            {song.coverImageUrl ? (
                              <img
                                src={song.coverImageUrl.startsWith('http') 
                                  ? song.coverImageUrl 
                                  : `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000'}${song.coverImageUrl}`}
                                alt={song.title}
                                className="h-12 w-12 rounded object-cover border border-gray-200"
                              />
                            ) : (
                              <div className="h-12 w-12 rounded bg-gray-100 flex items-center justify-center">
                                <MusicalNoteIcon className="h-6 w-6 text-gray-400" />
                              </div>
                            )}
                            <div className="flex-1 min-w-0">
                              <p className="text-sm font-medium text-gray-900 truncate">{song.title}</p>
                              <p className="text-xs text-gray-500 truncate">
                                {song.artist?.stageName || 'Artista desconocido'}
                              </p>
                            </div>
                            <div className="flex items-center gap-4 text-xs text-gray-500">
                              <div className="flex items-center gap-1">
                                <ClockIcon className="h-3 w-3" />
                                {formatDurationShort(song.duration)}
                              </div>
                            </div>
                          </div>
                            );
                          })
                          .filter(Boolean)}
                      </div>
                    ) : (
                      <div className="py-8 text-center text-sm text-gray-500 border border-gray-200 rounded-lg">
                        Esta playlist no tiene canciones aún.
                      </div>
                    )}
                  </div>
                </div>
              ) : (
                <div className="py-12 text-center text-sm text-gray-500">
                  No se pudieron cargar los detalles de la playlist.
                </div>
              )}
            </div>

            <div className="flex items-center justify-end gap-3 border-t border-gray-200 px-6 py-4 sticky bottom-0 bg-white">
              <button
                onClick={closeDetailsModal}
                className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-gray-300 hover:text-gray-700"
              >
                Cerrar
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

