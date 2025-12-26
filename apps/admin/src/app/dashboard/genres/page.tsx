'use client';

import { useMemo, useState } from 'react';
import { toast } from 'react-hot-toast';
import {
  ArrowPathIcon,
  MagnifyingGlassIcon,
  XMarkIcon,
  TrashIcon,
  PlusIcon,
  PencilIcon,
  MusicalNoteIcon,
  ClockIcon,
  PlayIcon,
} from '@heroicons/react/24/outline';

import { useGenres, useDeleteGenre, useCreateGenre, useUpdateGenre, GenreModel } from '@/hooks/useGenres';
import { apiClient } from '@/lib/api';
import { useQuery } from 'react-query';
import type { SongModel } from '@/types/song';

const PAGE_SIZE = 20;

// Componente para la fila de género
function GenreRow({
  genre,
  onEdit,
  onDelete,
  onViewSongs,
  isDeleting,
}: {
  genre: GenreModel;
  onEdit: (genre: GenreModel) => void;
  onDelete: (genre: GenreModel) => void;
  onViewSongs: (genre: GenreModel) => void;
  isDeleting: boolean;
}) {
  return (
    <tr className="hover:bg-gray-50 transition">
      <td className="py-4 px-4">
        <div className="flex items-center gap-3">
          {genre.imageUrl ? (
            <div className="h-10 w-10 flex-shrink-0 rounded-lg overflow-hidden shadow-sm">
              <img
                src={genre.imageUrl}
                alt={genre.name}
                className="h-full w-full object-cover"
                onError={(e) => {
                  // Si la imagen falla, mostrar el fallback
                  const target = e.target as HTMLImageElement;
                  target.style.display = 'none';
                  const parent = target.parentElement;
                  if (parent) {
                    parent.innerHTML = `
                      <div class="h-10 w-10 flex-shrink-0 rounded-lg flex items-center justify-center text-white font-semibold shadow-sm" style="background-color: ${genre.colorHex || '#6B7280'}">
                        ${genre.name.charAt(0).toUpperCase()}
                      </div>
                    `;
                  }
                }}
              />
            </div>
          ) : (
            <div
              className="h-10 w-10 flex-shrink-0 rounded-lg flex items-center justify-center text-white font-semibold shadow-sm"
              style={{
                backgroundColor: genre.colorHex || '#6B7280',
              }}
            >
              {genre.name.charAt(0).toUpperCase()}
            </div>
          )}
          <div className="min-w-0 flex-1">
            <button
              onClick={() => onViewSongs(genre)}
              className="text-sm font-medium text-gray-900 hover:text-brown-700 transition cursor-pointer text-left"
            >
              {genre.name}
            </button>
            {genre.description && (
              <p className="text-xs text-gray-500 truncate max-w-md">{genre.description}</p>
            )}
          </div>
        </div>
      </td>
      <td className="py-4 px-4">
        <div className="flex items-center gap-2">
          <div
            className="h-4 w-4 rounded-full border border-gray-300"
            style={{
              backgroundColor: genre.colorHex || '#6B7280',
            }}
          />
          <span className="text-xs text-gray-600 font-mono">{genre.colorHex || 'Sin color'}</span>
        </div>
      </td>
      <td className="py-4 px-4">
        <div className="flex items-center gap-4 text-xs text-gray-600">
          <div className="flex items-center gap-1">
            <MusicalNoteIcon className="h-3 w-3" />
            {genre.songCount?.toLocaleString('es-ES') || 0} canciones
          </div>
        </div>
      </td>
      <td className="py-4 px-4 text-right">
        <div className="flex items-center justify-end gap-2">
          <button
            onClick={() => onEdit(genre)}
            className="inline-flex items-center rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-600 transition hover:border-brown-500 hover:text-brown-700 disabled:cursor-not-allowed disabled:opacity-60"
            disabled={isDeleting}
          >
            <PencilIcon className="h-4 w-4" />
            <span className="ml-1">Editar</span>
          </button>
          <button
            onClick={() => onDelete(genre)}
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

export default function GenresPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showSongsModal, setShowSongsModal] = useState(false);
  const [selectedGenre, setSelectedGenre] = useState<GenreModel | null>(null);
  const [songsPage, setSongsPage] = useState(1);
  const [editingGenre, setEditingGenre] = useState<GenreModel | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    colorHex: '#6B7280',
  });
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);

  const { data, isLoading, isFetching, refetch, error } = useGenres({ page, limit: PAGE_SIZE, all: false, enabled: true });
  const genres = data?.genres ?? [];
  
  // Debug: Verificar datos recibidos
  if (typeof window !== 'undefined' && process.env.NODE_ENV === 'development') {
    console.log('[GenresPage] Datos recibidos:', { data, genres, total: data?.total, error });
  }
  const { mutateAsync: createGenre } = useCreateGenre();
  const { mutateAsync: updateGenre } = useUpdateGenre();
  const { mutateAsync: deleteGenre } = useDeleteGenre();

  // Obtener canciones del género seleccionado
  const { data: songsData, isLoading: isLoadingSongs } = useQuery(
    ['songsByGenre', selectedGenre?.id, songsPage],
    async () => {
      if (!selectedGenre) return null;
      const response = await apiClient.getSongsByGenre(selectedGenre.id, songsPage, 50);
      return response.data;
    },
    {
      enabled: !!selectedGenre && showSongsModal,
      keepPreviousData: true,
    }
  );

  const filteredGenres = useMemo(() => {
    if (!search.trim()) return genres;
    const query = search.toLowerCase();
    return genres.filter((genre) => {
      return (
        genre.name.toLowerCase().includes(query) ||
        genre.description?.toLowerCase().includes(query)
      );
    });
  }, [genres, search]);

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

  const openCreateModal = () => {
    setFormData({
      name: '',
      description: '',
      colorHex: '#6B7280',
    });
    setImageFile(null);
    setImagePreview(null);
    setShowCreateModal(true);
  };

  const openEditModal = (genre: GenreModel) => {
    setEditingGenre(genre);
    setFormData({
      name: genre.name,
      description: genre.description || '',
      colorHex: genre.colorHex || '#6B7280',
    });
    setImageFile(null);
    setImagePreview(genre.imageUrl || null);
    setShowEditModal(true);
  };

  const closeModals = () => {
    setShowCreateModal(false);
    setShowEditModal(false);
    setEditingGenre(null);
    setFormData({
      name: '',
      description: '',
      colorHex: '#6B7280',
    });
    setImageFile(null);
    setImagePreview(null);
  };

  const handleImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setImageFile(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setImagePreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.name.trim()) {
      toast.error('El nombre del género es requerido');
      return;
    }

    try {
      const genre = await createGenre({
        name: formData.name.trim(),
        description: formData.description.trim() || undefined,
        colorHex: formData.colorHex || undefined,
      });
      
      // Si hay una imagen, subirla después de crear el género
      if (imageFile && genre?.id) {
        await apiClient.uploadGenreImage(genre.id, imageFile);
      }
      
      closeModals();
    } catch (error) {
      // Error manejado por el hook
    }
  };

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingGenre) return;
    if (!formData.name.trim()) {
      toast.error('El nombre del género es requerido');
      return;
    }

    try {
      await updateGenre({
        id: editingGenre.id,
        data: {
          name: formData.name.trim(),
          description: formData.description.trim() || undefined,
          colorHex: formData.colorHex || undefined,
        },
      });
      
      // Si hay una nueva imagen, subirla
      if (imageFile) {
        await apiClient.uploadGenreImage(editingGenre.id, imageFile);
      }
      
      closeModals();
    } catch (error) {
      // Error manejado por el hook
    }
  };

  const handleDelete = async (genre: GenreModel) => {
    const confirmed = window.confirm(
      `¿Seguro que deseas eliminar el género "${genre.name}"?\n\n${
        genre.songCount && genre.songCount > 0
          ? `⚠️ Advertencia: Este género está siendo usado por ${genre.songCount} canción(es). No se podrá eliminar si está en uso.`
          : ''
      }`
    );
    if (!confirmed) return;

    try {
      setDeletingId(genre.id);
      await deleteGenre(genre.id);
    } finally {
      setDeletingId(null);
    }
  };

  const handleViewSongs = (genre: GenreModel) => {
    setSelectedGenre(genre);
    setSongsPage(1);
    setShowSongsModal(true);
  };

  const closeSongsModal = () => {
    setShowSongsModal(false);
    setSelectedGenre(null);
    setSongsPage(1);
  };

  const formatDuration = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Gestionar géneros musicales</h1>
            <p className="mt-1 text-sm text-gray-500">
              Crea, edita y gestiona los géneros musicales del catálogo.
            </p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => refetch()}
              className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-brown-600 hover:text-brown-700"
            >
              <ArrowPathIcon className={`h-4 w-4 ${isFetching ? 'animate-spin' : ''}`} />
              Actualizar
            </button>
            <button
              onClick={openCreateModal}
              className="flex items-center gap-2 rounded-lg bg-brown-700 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-brown-800"
            >
              <PlusIcon className="h-4 w-4" />
              Crear género
            </button>
          </div>
        </div>
            <div className="bg-white border border-gray-200 rounded-2xl shadow-sm p-6">
              <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                <div className="relative w-full sm:w-72">
                  <input
                    type="text"
                    value={search}
                    onChange={(event) => setSearch(event.target.value)}
                    placeholder="Buscar por nombre o descripción..."
                    className="w-full rounded-full border border-gray-200 bg-gray-50 px-4 py-2 pl-10 text-sm text-gray-800 focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-100"
                  />
                  <MagnifyingGlassIcon className="h-5 w-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                </div>
                <p className="text-sm text-gray-500">{total.toLocaleString('es-ES')} géneros en total</p>
              </div>

              <div className="mt-6 overflow-hidden rounded-xl border border-gray-200">
                <table className="min-w-full divide-y divide-gray-200 bg-white">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Género
                      </th>
                      <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Color
                      </th>
                      <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Uso
                      </th>
                      <th className="py-3 px-4 text-right text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Acciones
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {isLoading ? (
                      <tr>
                        <td colSpan={4} className="py-12 text-center text-sm text-gray-500">
                          Cargando géneros...
                        </td>
                      </tr>
                    ) : error ? (
                      <tr>
                        <td colSpan={4} className="py-12 text-center">
                          <p className="text-sm text-red-600 mb-2">Error al cargar géneros</p>
                          <p className="text-xs text-gray-500">{error instanceof Error ? error.message : 'Error desconocido'}</p>
                        </td>
                      </tr>
                    ) : filteredGenres.length === 0 ? (
                      <tr>
                        <td colSpan={4} className="py-12 text-center">
                          <p className="text-sm text-gray-500 mb-2">
                            {search.trim() ? 'No se encontraron géneros que coincidan con la búsqueda.' : 'No hay géneros registrados.'}
                          </p>
                          {!search.trim() && (
                            <p className="text-xs text-gray-400 mt-1">
                              Haz clic en "Crear género" para agregar el primer género al catálogo.
                            </p>
                          )}
                        </td>
                      </tr>
                    ) : (
                      filteredGenres.map((genre) => (
                        <GenreRow
                          key={genre.id}
                          genre={genre}
                          onEdit={openEditModal}
                          onDelete={handleDelete}
                          onViewSongs={handleViewSongs}
                          isDeleting={deletingId === genre.id}
                        />
                      ))
                    )}
                  </tbody>
                </table>
              </div>

              <div className="mt-6 flex flex-col items-center justify-between gap-4 sm:flex-row">
                <p className="text-sm text-gray-500">
                  Página {page} de {totalPages}
                </p>
                <div className="flex items-center gap-2">
                  <button
                    onClick={handlePrev}
                    disabled={page === 1}
                    className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-500 transition hover:border-brown-600 hover:text-brown-700 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Anterior
                  </button>
                  <button
                    onClick={handleNext}
                    disabled={page === totalPages}
                    className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-500 transition hover:border-brown-600 hover:text-brown-700 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Siguiente
                  </button>
                </div>
              </div>
            </div>
      </div>

      {/* Modal para crear género */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm px-4">
          <div className="w-full max-w-lg rounded-2xl bg-white shadow-xl">
            <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
              <div>
                <h2 className="text-lg font-semibold text-gray-900">Crear nuevo género</h2>
                <p className="text-sm text-gray-500">Agrega un nuevo género musical al catálogo</p>
              </div>
              <button
                onClick={closeModals}
                className="rounded-full p-1 text-gray-400 transition hover:bg-gray-100 hover:text-gray-600"
                aria-label="Cerrar"
              >
                <XMarkIcon className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={handleCreate} className="px-6 py-6 space-y-4">
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Nombre del género *
                </label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData((prev) => ({ ...prev, name: e.target.value }))}
                  required
                  maxLength={50}
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-100"
                  placeholder="Ej. Reggaeton"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Descripción (opcional)
                </label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData((prev) => ({ ...prev, description: e.target.value }))}
                  rows={3}
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-100"
                  placeholder="Descripción del género musical..."
                />
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Color (opcional)
                </label>
                <div className="flex items-center gap-3">
                  <input
                    type="color"
                    value={formData.colorHex}
                    onChange={(e) => setFormData((prev) => ({ ...prev, colorHex: e.target.value }))}
                    className="h-10 w-20 rounded-lg border border-gray-200 cursor-pointer"
                  />
                  <input
                    type="text"
                    value={formData.colorHex}
                    onChange={(e) => {
                      const value = e.target.value;
                      if (/^#[0-9A-Fa-f]{0,6}$/.test(value)) {
                        setFormData((prev) => ({ ...prev, colorHex: value }));
                      }
                    }}
                    pattern="^#[0-9A-Fa-f]{6}$"
                    maxLength={7}
                    className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm font-mono focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-100"
                    placeholder="#FF5733"
                  />
                </div>
                <p className="mt-1 text-xs text-gray-400">Formato: #RRGGBB (ej: #FF5733)</p>
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Imagen del género (opcional)
                </label>
                <div className="space-y-3">
                  {imagePreview && (
                    <div className="relative w-full h-48 rounded-lg overflow-hidden border border-gray-200">
                      <img
                        src={imagePreview}
                        alt="Vista previa"
                        className="w-full h-full object-cover"
                      />
                    </div>
                  )}
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    onChange={handleImageChange}
                    className="w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-brown-50 file:text-brown-700 hover:file:bg-brown-100"
                  />
                  <p className="text-xs text-gray-400">Formatos permitidos: JPG, PNG, WEBP (máx. 10MB)</p>
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={closeModals}
                  className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-gray-300 hover:text-gray-700"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="inline-flex items-center rounded-lg bg-brown-700 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-brown-800"
                >
                  Crear género
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal para editar género */}
      {showEditModal && editingGenre && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm px-4">
          <div className="w-full max-w-lg rounded-2xl bg-white shadow-xl">
            <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
              <div>
                <h2 className="text-lg font-semibold text-gray-900">Editar género</h2>
                <p className="text-sm text-gray-500">Modifica la información del género</p>
              </div>
              <button
                onClick={closeModals}
                className="rounded-full p-1 text-gray-400 transition hover:bg-gray-100 hover:text-gray-600"
                aria-label="Cerrar"
              >
                <XMarkIcon className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={handleUpdate} className="px-6 py-6 space-y-4">
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Nombre del género *
                </label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData((prev) => ({ ...prev, name: e.target.value }))}
                  required
                  maxLength={50}
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-100"
                  placeholder="Ej. Reggaeton"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Descripción (opcional)
                </label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData((prev) => ({ ...prev, description: e.target.value }))}
                  rows={3}
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-100"
                  placeholder="Descripción del género musical..."
                />
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Color (opcional)
                </label>
                <div className="flex items-center gap-3">
                  <input
                    type="color"
                    value={formData.colorHex}
                    onChange={(e) => setFormData((prev) => ({ ...prev, colorHex: e.target.value }))}
                    className="h-10 w-20 rounded-lg border border-gray-200 cursor-pointer"
                  />
                  <input
                    type="text"
                    value={formData.colorHex}
                    onChange={(e) => {
                      const value = e.target.value;
                      if (/^#[0-9A-Fa-f]{0,6}$/.test(value)) {
                        setFormData((prev) => ({ ...prev, colorHex: value }));
                      }
                    }}
                    pattern="^#[0-9A-Fa-f]{6}$"
                    maxLength={7}
                    className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm font-mono focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-100"
                    placeholder="#FF5733"
                  />
                </div>
                <p className="mt-1 text-xs text-gray-400">Formato: #RRGGBB (ej: #FF5733)</p>
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Imagen del género (opcional)
                </label>
                <div className="space-y-3">
                  {imagePreview && (
                    <div className="relative w-full h-48 rounded-lg overflow-hidden border border-gray-200">
                      <img
                        src={imagePreview}
                        alt="Vista previa"
                        className="w-full h-full object-cover"
                      />
                    </div>
                  )}
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    onChange={handleImageChange}
                    className="w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-brown-50 file:text-brown-700 hover:file:bg-brown-100"
                  />
                  <p className="text-xs text-gray-400">Formatos permitidos: JPG, PNG, WEBP (máx. 10MB)</p>
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={closeModals}
                  className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-gray-300 hover:text-gray-700"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="inline-flex items-center rounded-lg bg-brown-700 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-brown-800"
                >
                  Guardar cambios
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal para ver canciones del género */}
      {showSongsModal && selectedGenre && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm px-4">
          <div className="w-full max-w-4xl max-h-[90vh] rounded-2xl bg-white shadow-xl flex flex-col">
            <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4 flex-shrink-0">
              <div>
                <h2 className="text-lg font-semibold text-gray-900">
                  Canciones del género: {selectedGenre.name}
                </h2>
                <p className="text-sm text-gray-500">
                  {songsData?.total || 0} canciones en total
                </p>
              </div>
              <button
                onClick={closeSongsModal}
                className="rounded-full p-1 text-gray-400 transition hover:bg-gray-100 hover:text-gray-600"
                aria-label="Cerrar"
              >
                <XMarkIcon className="h-5 w-5" />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto px-6 py-4">
              {isLoadingSongs ? (
                <div className="py-12 text-center text-sm text-gray-500">
                  Cargando canciones...
                </div>
              ) : songsData?.songs && songsData.songs.length > 0 ? (
                <div className="space-y-3">
                  {songsData.songs.map((song: SongModel) => {
                    // Construir URL completa de la portada (usar coverArtUrl primero, luego coverImageUrl)
                    const getCoverUrl = () => {
                      const imageUrl = song.coverArtUrl || song.coverImageUrl;
                      if (!imageUrl) return null;
                      
                      // Si ya es una URL completa, usarla tal cual
                      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
                        return imageUrl;
                      }
                      
                      // Si es una ruta relativa, construir URL completa
                      if (imageUrl.startsWith('/')) {
                        const baseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';
                        return `${baseUrl}${imageUrl}`;
                      }
                      
                      // Si es una ruta sin /, agregar el prefijo del backend
                      const baseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';
                      return `${baseUrl}/uploads/covers/${imageUrl}`;
                    };
                    
                    const coverUrl = getCoverUrl();
                    
                    return (
                      <div
                        key={song.id}
                        className="flex items-center gap-4 p-3 rounded-lg border border-gray-200 hover:bg-gray-50 transition"
                      >
                        <div className="h-16 w-16 flex-shrink-0 rounded-lg overflow-hidden shadow-sm bg-gray-100">
                          {coverUrl ? (
                            <img
                              src={coverUrl}
                              alt={song.title}
                              className="h-full w-full object-cover"
                              onError={(e) => {
                                const target = e.target as HTMLImageElement;
                                const parent = target.parentElement;
                                if (parent) {
                                  parent.innerHTML = `
                                    <div class="h-full w-full flex items-center justify-center bg-gray-200">
                                      <svg class="h-8 w-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
                                      </svg>
                                    </div>
                                  `;
                                }
                              }}
                            />
                          ) : (
                            <div className="h-full w-full flex items-center justify-center bg-gray-200">
                              <MusicalNoteIcon className="h-8 w-8 text-gray-400" />
                            </div>
                          )}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium text-gray-900 truncate">
                            {song.title}
                          </p>
                          <p className="text-xs text-gray-500 truncate">
                            {song.artist?.stageName || 'Artista desconocido'}
                          </p>
                        </div>
                        <div className="flex items-center gap-4 text-xs text-gray-500">
                          <div className="flex items-center gap-1">
                            <ClockIcon className="h-4 w-4" />
                            {formatDuration(song.duration)}
                          </div>
                          <div className="flex items-center gap-1">
                            <PlayIcon className="h-4 w-4" />
                            {song.totalStreams?.toLocaleString('es-ES') || 0}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <div className="py-12 text-center">
                  <p className="text-sm text-gray-500 mb-2">
                    No hay canciones en este género.
                  </p>
                </div>
              )}
            </div>

            {songsData && songsData.total > 50 && (
              <div className="border-t border-gray-200 px-6 py-4 flex items-center justify-between flex-shrink-0">
                <p className="text-sm text-gray-500">
                  Mostrando {songsData.songs.length} de {songsData.total} canciones
                </p>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setSongsPage((p) => Math.max(1, p - 1))}
                    disabled={songsPage === 1}
                    className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-500 transition hover:border-brown-600 hover:text-brown-700 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Anterior
                  </button>
                  <span className="text-sm text-gray-500">
                    Página {songsPage}
                  </span>
                  <button
                    onClick={() => setSongsPage((p) => p + 1)}
                    disabled={!songsData || songsData.songs.length < 50}
                    className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-500 transition hover:border-brown-600 hover:text-brown-700 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Siguiente
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  );
}

