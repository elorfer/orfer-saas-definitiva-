'use client';

import { useState } from 'react';
import { toast } from 'react-hot-toast';
import {
  ArrowPathIcon,
  MagnifyingGlassIcon,
  MusicalNoteIcon,
  XMarkIcon,
  CheckCircleIcon,
  TrashIcon,
  PlusIcon,
  PencilIcon,
  ListBulletIcon,
  PhotoIcon,
  PlayIcon,
} from '@heroicons/react/24/outline';
import { usePlaylists, useCreatePlaylist, useDeletePlaylist, useUpdatePlaylist } from '@/hooks/usePlaylists';
import { usePresignedUpload } from '@/hooks/usePresignedUpload';
import { apiClient } from '@/lib/api';
import { useQuery } from 'react-query';

const PAGE_SIZE = 20;

const resolveImageUrl = (url: string | undefined | null) => {
  if (!url) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/')) return `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000'}${url}`;
  return `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000'}/uploads/covers/${url}`;
};

function PlaylistRow({ playlist, onDelete, onEdit, onManageSongs, isDeleting }: any) {
  const [imgError, setImgError] = useState(false);
  const coverUrl = resolveImageUrl(playlist.coverArtUrl);

  return (
    <tr className="hover:bg-gray-50 transition">
      <td className="py-4 px-4">
        <div className="flex items-center gap-3">
          {coverUrl && !imgError ? (
            <div className="h-12 w-12 flex-shrink-0 rounded-lg overflow-hidden border border-gray-200 shadow-sm">
              <img
                src={coverUrl}
                alt={playlist.name}
                className="h-full w-full object-cover"
                onError={() => setImgError(true)}
              />
            </div>
          ) : (
            <div className="h-12 w-12 flex-shrink-0 rounded-lg bg-gray-100 flex items-center justify-center text-gray-400 border border-gray-200 shadow-sm">
              <ListBulletIcon className="h-6 w-6" />
            </div>
          )}
          <div className="min-w-0 flex-1">
            <p className="text-sm font-medium text-gray-900 truncate">{playlist.name}</p>
            {playlist.description && (
              <p className="text-xs text-gray-500 truncate max-w-sm">{playlist.description}</p>
            )}
          </div>
        </div>
      </td>
      <td className="py-4 px-4">
        <div className="flex items-center gap-1 text-xs text-gray-600">
          <MusicalNoteIcon className="h-3 w-3" />
          {playlist.totalTracks || 0} canciones
        </div>
      </td>
      <td className="py-4 px-4">
        {playlist.isPublic ? (
          <span className="inline-flex items-center rounded-full bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">
            Pública
          </span>
        ) : (
          <span className="inline-flex items-center rounded-full bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">
            Privada
          </span>
        )}
      </td>
      <td className="py-4 px-4 text-right">
        <div className="flex items-center justify-end gap-2">
          <button
            onClick={() => onManageSongs(playlist)}
            className="inline-flex items-center rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-600 transition hover:border-blue-300 hover:text-blue-600"
          >
            <MusicalNoteIcon className="h-4 w-4 mr-1" />
            Canciones
          </button>
          <button
            onClick={() => onEdit(playlist)}
            className="inline-flex items-center rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-600 transition hover:border-brown-500 hover:text-brown-700"
          >
            <PencilIcon className="h-4 w-4 mr-1" />
            Editar
          </button>
          <button
            onClick={() => onDelete(playlist)}
            disabled={isDeleting}
            className="inline-flex items-center rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-500 transition hover:border-red-300 hover:text-red-600 disabled:opacity-50"
          >
            <TrashIcon className={`h-4 w-4 ${isDeleting ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </td>
    </tr>
  );
}

export default function PlaylistsPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');

  // Estados para Modals
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showSongsModal, setShowSongsModal] = useState(false);

  // Estados de datos en edición
  const [selectedPlaylist, setSelectedPlaylist] = useState<any | null>(null);
  const [playlistForm, setPlaylistForm] = useState({
    name: '',
    description: '',
    isPublic: true,
  });
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [coverPreview, setCoverPreview] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  // Estado de subida
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Hooks de datos
  const { data, isLoading, isFetching, refetch, error } = usePlaylists({ page, limit: PAGE_SIZE });
  const playlists = data?.playlists || [];
  const total = data?.total || 0;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const { mutateAsync: createPlaylist } = useCreatePlaylist();
  const { mutateAsync: updatePlaylist } = useUpdatePlaylist();
  const { mutateAsync: deletePlaylist } = useDeletePlaylist();

  // Hook de subida directa a R2
  const { uploadFile: uploadCoverImage } = usePresignedUpload({
    folder: 'images', // Compresión automática en el cliente (si está configurada en el hook)
    onError: (err) => toast.error(`Error al subir imagen: ${err.message}`),
  });

  const handleNext = () => page < totalPages && setPage(p => p + 1);
  const handlePrev = () => page > 1 && setPage(p => p - 1);

  const openCreateModal = () => {
    setPlaylistForm({ name: '', description: '', isPublic: true });
    setCoverFile(null);
    setCoverPreview(null);
    setIsSubmitting(false);
    setShowCreateModal(true);
  };

  const openEditModal = (playlist: any) => {
    setSelectedPlaylist(playlist);
    setPlaylistForm({
      name: playlist.name,
      description: playlist.description || '',
      isPublic: playlist.isPublic,
    });
    setCoverFile(null);
    setCoverPreview(resolveImageUrl(playlist.coverArtUrl));
    setIsSubmitting(false);
    setShowEditModal(true);
  };

  const openSongsModal = (playlist: any) => {
    setSelectedPlaylist(playlist);
    setShowSongsModal(true);
  };

  const closeModals = () => {
    if (isSubmitting) return;
    setShowCreateModal(false);
    setShowEditModal(false);
    setShowSongsModal(false);
    setSelectedPlaylist(null);
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      if (!file.type.startsWith('image/')) {
        toast.error('Por favor selecciona un archivo de imagen válido');
        return;
      }
      setCoverFile(file);
      const reader = new FileReader();
      reader.onloadend = () => setCoverPreview(reader.result as string);
      reader.readAsDataURL(file);
    }
  };

  const handleCreatePlaylist = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!playlistForm.name.trim()) {
      toast.error('El nombre es obligatorio');
      return;
    }

    try {
      setIsSubmitting(true);
      let coverUrl = undefined;

      // 1. Subir imagen directamente a R2 (si existe)
      if (coverFile) {
        toast.loading('Subiendo portada...', { id: 'playlist-upload' });
        const result = await uploadCoverImage(coverFile);
        coverUrl = result.publicUrl;
        toast.success('Portada subida', { id: 'playlist-upload' });
      }

      // 2. Crear playlist con la URL
      await createPlaylist({
        name: playlistForm.name,
        description: playlistForm.description,
        isPublic: playlistForm.isPublic,
        coverArtUrl: coverUrl,
      });

      toast.success('Playlist creada correctamente');
      closeModals();
    } catch (err: any) {
      console.error(err);
      toast.error(err.message || 'Error al crear playlist');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleUpdatePlaylist = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedPlaylist) return;

    try {
      setIsSubmitting(true);
      let coverUrl = selectedPlaylist.coverArtUrl; // Mantener la existente por defecto

      // 1. Subir NUEVA imagen si se seleccionó
      if (coverFile) {
        toast.loading('Actualizando portada...', { id: 'playlist-upload' });
        const result = await uploadCoverImage(coverFile);
        coverUrl = result.publicUrl;
        toast.success('Portada actualizada', { id: 'playlist-upload' });
      }

      // 2. Actualizar datos
      await updatePlaylist({
        id: selectedPlaylist.id,
        data: {
          name: playlistForm.name,
          description: playlistForm.description,
          isPublic: playlistForm.isPublic,
          coverArtUrl: coverUrl,
        },
      });

      toast.success('Playlist actualizada');
      closeModals();
    } catch (err: any) {
      console.error(err);
      toast.error(err.message || 'Error al actualizar playlist');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeletePlaylist = async (playlist: any) => {
    if (!window.confirm(`¿Eliminar playlist "${playlist.name}"?`)) return;
    try {
      setDeletingId(playlist.id);
      await deletePlaylist(playlist.id);
      toast.success('Playlist eliminada');
    } catch (err) {
      toast.error('Error al eliminar playlist');
    } finally {
      setDeletingId(null);
    }
  };

  // Filtrado local básico si quieres (opcional, ya que la API no parece tener búsqueda server-side todavía en este hook)
  const filteredPlaylists = playlists.filter((p: any) =>
    p.name.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Gestionar Playlists</h1>
            <p className="mt-1 text-sm text-gray-500">Crea y organiza las listas de reproducción de la plataforma.</p>
          </div>
          <div className="flex items-center gap-2">
            <button onClick={() => refetch()} className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:text-brown-700 transition">
              <ArrowPathIcon className={`h-4 w-4 ${isFetching ? 'animate-spin' : ''}`} />
              Actualizar
            </button>
            <button onClick={openCreateModal} className="flex items-center gap-2 rounded-lg bg-brown-700 px-4 py-2 text-sm font-semibold text-white hover:bg-brown-800 transition shadow-sm">
              <PlusIcon className="h-4 w-4" />
              Nueva Playlist
            </button>
          </div>
        </div>

        <div className="bg-white border border-gray-200 rounded-2xl shadow-sm p-6">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between mb-6">
            <div className="relative w-full sm:w-72">
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Buscar playlists..."
                className="w-full rounded-full border border-gray-200 bg-gray-50 px-4 py-2 pl-10 text-sm text-gray-800 focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-100"
              />
              <MagnifyingGlassIcon className="h-5 w-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
            </div>
            <p className="text-sm text-gray-500">{total} playlists en total</p>
          </div>

          <div className="overflow-hidden rounded-xl border border-gray-200">
            <table className="min-w-full divide-y divide-gray-200 bg-white">
              <thead className="bg-gray-50">
                <tr>
                  <th className="py-3 px-4 text-left text-xs font-semibold uppercase text-gray-500">Playlist</th>
                  <th className="py-3 px-4 text-left text-xs font-semibold uppercase text-gray-500">Canciones</th>
                  <th className="py-3 px-4 text-left text-xs font-semibold uppercase text-gray-500">Visibilidad</th>
                  <th className="py-3 px-4 text-right text-xs font-semibold uppercase text-gray-500">Acciones</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {isLoading ? (
                  <tr><td colSpan={4} className="py-12 text-center text-gray-500">Cargando playlists...</td></tr>
                ) : filteredPlaylists.length === 0 ? (
                  <tr><td colSpan={4} className="py-12 text-center text-gray-500">No se encontraron playlists.</td></tr>
                ) : (
                  filteredPlaylists.map((playlist: any) => (
                    <PlaylistRow
                      key={playlist.id}
                      playlist={playlist}
                      onDelete={handleDeletePlaylist}
                      onEdit={openEditModal}
                      onManageSongs={openSongsModal}
                      isDeleting={deletingId === playlist.id}
                    />
                  ))
                )}
              </tbody>
            </table>
          </div>

          {/* Paginación simple */}
          <div className="mt-6 flex flex-col items-center justify-between gap-4 sm:flex-row">
            <p className="text-sm text-gray-500">Página {page} de {totalPages}</p>
            <div className="flex items-center gap-2">
              <button onClick={handlePrev} disabled={page === 1} className="rounded-lg border px-4 py-2 text-sm disabled:opacity-50 hover:bg-gray-50">Anterior</button>
              <button onClick={handleNext} disabled={page === totalPages} className="rounded-lg border px-4 py-2 text-sm disabled:opacity-50 hover:bg-gray-50">Siguiente</button>
            </div>
          </div>
        </div>
      </div>

      {/* Modal CREATE/EDIT */}
      {(showCreateModal || showEditModal) && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm px-4">
          <div className="w-full max-w-lg bg-white rounded-2xl shadow-xl overflow-hidden">
            <div className="flex justify-between items-center px-6 py-4 border-b">
              <h3 className="text-lg font-semibold text-gray-900">
                {showCreateModal ? 'Crear Playlist' : 'Editar Playlist'}
              </h3>
              <button onClick={closeModals} disabled={isSubmitting} className="p-1 rounded-full hover:bg-gray-100 transition"><XMarkIcon className="h-5 w-5 text-gray-500" /></button>
            </div>
            <form onSubmit={showCreateModal ? handleCreatePlaylist : handleUpdatePlaylist} className="p-6 space-y-4">
              <div>
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Nombre *</label>
                <input
                  type="text"
                  required
                  disabled={isSubmitting}
                  className="w-full rounded-lg border-gray-200 text-sm focus:ring-brown-500 focus:border-brown-500"
                  placeholder="Ej. Éxitos de Verano"
                  value={playlistForm.name}
                  onChange={e => setPlaylistForm({ ...playlistForm, name: e.target.value })}
                />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Descripción</label>
                <textarea
                  rows={3}
                  disabled={isSubmitting}
                  className="w-full rounded-lg border-gray-200 text-sm focus:ring-brown-500 focus:border-brown-500"
                  placeholder="Breve descripción..."
                  value={playlistForm.description}
                  onChange={e => setPlaylistForm({ ...playlistForm, description: e.target.value })}
                />
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="isPublic"
                  disabled={isSubmitting}
                  checked={playlistForm.isPublic}
                  onChange={e => setPlaylistForm({ ...playlistForm, isPublic: e.target.checked })}
                  className="rounded border-gray-300 text-brown-600 focus:ring-brown-500"
                />
                <label htmlFor="isPublic" className="text-sm text-gray-700">Playlist pública (visible para todos)</label>
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-2">Portada (Opcional)</label>
                <div className={`border-2 border-dashed rounded-lg p-4 flex gap-4 transition ${isSubmitting ? 'bg-gray-50' : 'hover:border-brown-500'}`}>
                  {coverPreview ? (
                    <img src={coverPreview} alt="Preview" className="h-20 w-20 rounded-lg object-cover bg-gray-100" />
                  ) : (
                    <div className="h-20 w-20 rounded-lg bg-gray-100 flex items-center justify-center text-gray-400">
                      <PhotoIcon className="h-8 w-8" />
                    </div>
                  )}
                  <div className="flex-1 flex flex-col justify-center">
                    <input
                      type="file"
                      accept="image/*"
                      disabled={isSubmitting}
                      onChange={handleFileChange}
                      className="text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-brown-50 file:text-brown-700 hover:file:bg-brown-100"
                    />
                    <p className="text-xs text-gray-400 mt-1">Máx 5MB. JPG, PNG, WEBP.</p>
                  </div>
                </div>
              </div>

              <div className="pt-2 flex justify-end gap-2">
                <button type="button" onClick={closeModals} disabled={isSubmitting} className="px-4 py-2 border rounded-lg text-sm font-medium text-gray-600 hover:bg-gray-50">Cancelar</button>
                <button type="submit" disabled={isSubmitting} className="px-4 py-2 bg-brown-700 text-white rounded-lg text-sm font-semibold hover:bg-brown-800 disabled:bg-gray-400 flex items-center gap-2">
                  {isSubmitting && <ArrowPathIcon className="h-4 w-4 animate-spin" />}
                  {showCreateModal ? 'Crear Playlist' : 'Guardar Cambios'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Songs Management - Placeholder o implementación básica */}
      {showSongsModal && selectedPlaylist && (
        <PlaylistSongsModal playlist={selectedPlaylist} onClose={() => setShowSongsModal(false)} />
      )}
    </>
  );
}

// Subcomponente simple para gestionar canciones dentro de la playlist
// (Idealmente esto podría ser más complejo, permitiendo buscar y añadir canciones)
function PlaylistSongsModal({ playlist, onClose }: any) {
  const { data, isLoading } = useQuery(['playlist-songs', playlist.id], () => apiClient.getPlaylistSongs(playlist.id).then(res => res.data));
  const queryClient = useQueryClient();

  // Mutation para remover canción (ejemplo)
  const removeSong = async (songId: string) => {
    try {
      await apiClient.removeSongFromPlaylist(playlist.id, songId);
      toast.success('Canción removida');
      queryClient.invalidateQueries(['playlist-songs', playlist.id]);
      queryClient.invalidateQueries(['playlists']); // update count
    } catch (e) {
      toast.error('Error al remover canción');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm px-4">
      <div className="w-full max-w-3xl bg-white rounded-2xl shadow-xl overflow-hidden max-h-[80vh] flex flex-col">
        <div className="flex justify-between items-center px-6 py-4 border-b shrink-0">
          <div>
            <h3 className="text-lg font-semibold text-gray-900">Canciones en "{playlist.name}"</h3>
            <p className="text-xs text-gray-500">Gestiona el contenido de esta lista</p>
          </div>
          <button onClick={onClose} className="p-1 rounded-full hover:bg-gray-100 transition"><XMarkIcon className="h-5 w-5 text-gray-500" /></button>
        </div>

        <div className="flex-1 overflow-y-auto p-6">
          {isLoading ? (
            <div className="text-center py-10 text-gray-500">Cargando canciones...</div>
          ) : !data?.songs?.length ? (
            <div className="text-center py-10 text-gray-500">
              <p>Esta playlist está vacía.</p>
              <p className="text-xs mt-1">Agrega canciones desde la sección "Canciones" o "Explorar".</p>
            </div>
          ) : (
            <ul className="space-y-2">
              {data.songs.map((song: any) => (
                <li key={song.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition">
                  <div className="flex items-center gap-3">
                    {song.coverArtUrl ? (
                      <img src={resolveImageUrl(song.coverArtUrl)} className="h-10 w-10 rounded object-cover" alt="" />
                    ) : (
                      <div className="h-10 w-10 bg-gray-200 rounded flex items-center justify-center"><MusicalNoteIcon className="h-5 w-5 text-gray-400" /></div>
                    )}
                    <div>
                      <p className="text-sm font-medium text-gray-900 line-clamp-1">{song.title}</p>
                      <p className="text-xs text-gray-500 line-clamp-1">{song.artist?.stageName || 'Artista desconocido'}</p>
                    </div>
                  </div>
                  <button
                    onClick={() => removeSong(song.id)}
                    className="text-gray-400 hover:text-red-500 p-2"
                    title="Quitar de la playlist"
                  >
                    <XMarkIcon className="h-5 w-5" />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}
