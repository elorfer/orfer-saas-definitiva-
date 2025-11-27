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
} from '@heroicons/react/24/outline';

import { useGenres, useDeleteGenre, useCreateGenre, useUpdateGenre, GenreModel } from '@/hooks/useGenres';

const PAGE_SIZE = 20;

// Componente para la fila de género
function GenreRow({
  genre,
  onEdit,
  onDelete,
  isDeleting,
}: {
  genre: GenreModel;
  onEdit: (genre: GenreModel) => void;
  onDelete: (genre: GenreModel) => void;
  isDeleting: boolean;
}) {
  return (
    <tr className="hover:bg-gray-50 transition">
      <td className="py-4 px-4">
        <div className="flex items-center gap-3">
          <div
            className="h-10 w-10 flex-shrink-0 rounded-lg flex items-center justify-center text-white font-semibold shadow-sm"
            style={{
              backgroundColor: genre.colorHex || '#6B7280',
            }}
          >
            {genre.name.charAt(0).toUpperCase()}
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-sm font-medium text-gray-900">{genre.name}</p>
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
            className="inline-flex items-center rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-600 transition hover:border-purple-300 hover:text-purple-600 disabled:cursor-not-allowed disabled:opacity-60"
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
  const [editingGenre, setEditingGenre] = useState<GenreModel | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    colorHex: '#6B7280',
  });

  const { data, isLoading, isFetching, refetch, error } = useGenres({ page, limit: PAGE_SIZE, all: false, enabled: true });
  const genres = data?.genres ?? [];
  
  // Debug: Verificar datos recibidos
  if (typeof window !== 'undefined' && process.env.NODE_ENV === 'development') {
    console.log('[GenresPage] Datos recibidos:', { data, genres, total: data?.total, error });
  }
  const { mutateAsync: createGenre } = useCreateGenre();
  const { mutateAsync: updateGenre } = useUpdateGenre();
  const { mutateAsync: deleteGenre } = useDeleteGenre();

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
    setShowCreateModal(true);
  };

  const openEditModal = (genre: GenreModel) => {
    setEditingGenre(genre);
    setFormData({
      name: genre.name,
      description: genre.description || '',
      colorHex: genre.colorHex || '#6B7280',
    });
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
  };

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.name.trim()) {
      toast.error('El nombre del género es requerido');
      return;
    }

    try {
      await createGenre({
        name: formData.name.trim(),
        description: formData.description.trim() || undefined,
        colorHex: formData.colorHex || undefined,
      });
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
              className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-purple-400 hover:text-purple-600"
            >
              <ArrowPathIcon className={`h-4 w-4 ${isFetching ? 'animate-spin' : ''}`} />
              Actualizar
            </button>
            <button
              onClick={openCreateModal}
              className="flex items-center gap-2 rounded-lg bg-purple-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-purple-700"
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
                    className="w-full rounded-full border border-gray-200 bg-gray-50 px-4 py-2 pl-10 text-sm text-gray-800 focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
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
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
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
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
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
                    className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm font-mono focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                    placeholder="#FF5733"
                  />
                </div>
                <p className="mt-1 text-xs text-gray-400">Formato: #RRGGBB (ej: #FF5733)</p>
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
                  className="inline-flex items-center rounded-lg bg-purple-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-purple-700"
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
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
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
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
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
                    className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm font-mono focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                    placeholder="#FF5733"
                  />
                </div>
                <p className="mt-1 text-xs text-gray-400">Formato: #RRGGBB (ej: #FF5733)</p>
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
                  className="inline-flex items-center rounded-lg bg-purple-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-purple-700"
                >
                  Guardar cambios
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}

