'use client';

import { useMemo, useState, useRef } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { toast } from 'react-hot-toast';
import {
  ArrowPathIcon,
  MagnifyingGlassIcon,
  UsersIcon,
  HomeIcon,
  MusicalNoteIcon,
  ShieldCheckIcon,
  XMarkIcon,
  TrashIcon,
  PlusIcon,
  ClockIcon,
  PlayIcon,
  HeartIcon,
  CheckCircleIcon,
  DocumentArrowUpIcon,
  PhotoIcon,
  StarIcon,
  ListBulletIcon,
} from '@heroicons/react/24/outline';

import { useSongs, useUploadSong, useDeleteSong, useCreateSong } from '@/hooks/useSongs';
import { useArtists } from '@/hooks/useArtists';
import type { SongModel } from '@/types/song';

const PAGE_SIZE = 10;
const DEFAULT_UPLOAD_FORM = {
  file: null as File | null,
  coverFile: null as File | null,
  title: '',
  artistId: '',
};

const statusLabels: Record<string, { label: string; badge: string }> = {
  draft: { label: 'Borrador', badge: 'bg-gray-100 text-gray-700' },
  published: { label: 'Publicada', badge: 'bg-green-100 text-green-700' },
  archived: { label: 'Archivada', badge: 'bg-yellow-100 text-yellow-700' },
};

const formatDuration = (seconds: number): string => {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs.toString().padStart(2, '0')}`;
};

// Componente para la fila de canción con manejo de imagen
function SongRow({ 
  song, 
  statusInfo, 
  onDelete, 
  isDeleting 
}: { 
  song: SongModel; 
  statusInfo: { label: string; badge: string };
  onDelete: (song: SongModel) => void;
  isDeleting: boolean;
}) {
  const [imageError, setImageError] = useState(false);
  
  // Construir URL completa de la portada
  const getCoverUrl = () => {
    if (!song.coverImageUrl) {
      if (process.env.NODE_ENV === 'development') {
        console.log(`⚠️ Canción "${song.title}" sin portada:`, {
          id: song.id,
          coverImageUrl: song.coverImageUrl,
          duration: song.duration,
        });
      }
      return null;
    }
    
    // Si ya es una URL completa, usarla tal cual
    if (song.coverImageUrl.startsWith('http://') || song.coverImageUrl.startsWith('https://')) {
      return song.coverImageUrl;
    }
    
    // Si es una ruta relativa, construir URL completa
    if (song.coverImageUrl.startsWith('/')) {
      const baseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';
      return `${baseUrl}${song.coverImageUrl}`;
    }
    
    // Si es una ruta sin /, agregar el prefijo del backend
    const baseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';
    return `${baseUrl}/uploads/covers/${song.coverImageUrl}`;
  };
  
  const coverUrl = getCoverUrl();
  
  // Debug: mostrar si la duración es 0
  if (song.duration === 0 && process.env.NODE_ENV === 'development') {
    console.log(`⚠️ Canción "${song.title}" con duración 0:`, {
      id: song.id,
      duration: song.duration,
      coverImageUrl: song.coverImageUrl,
      coverUrl,
    });
  }

  return (
    <tr className="hover:bg-gray-50 transition">
      <td className="py-4 px-4">
        <div className="flex items-center gap-3">
          {coverUrl && !imageError ? (
            <div className="h-12 w-12 flex-shrink-0 rounded-lg overflow-hidden border border-gray-200 bg-gray-100 shadow-sm">
              <img
                src={coverUrl}
                alt={`Portada de ${song.title}`}
                className="h-full w-full object-cover"
                onError={() => {
                  console.warn('Error cargando portada:', coverUrl);
                  setImageError(true);
                }}
                loading="lazy"
              />
            </div>
          ) : (
            <div className="h-12 w-12 flex-shrink-0 rounded-lg bg-gradient-to-br from-purple-500 to-purple-600 text-white flex items-center justify-center shadow-sm">
              <MusicalNoteIcon className="h-5 w-5" />
            </div>
          )}
          <div className="min-w-0 flex-1">
            <p className="text-sm font-medium text-gray-900 truncate">{song.title}</p>
            <p className="text-xs text-gray-500">
              {new Date(song.createdAt).toLocaleDateString('es-ES')}
            </p>
          </div>
        </div>
      </td>
      <td className="py-4 px-4">
        <p className="text-sm text-gray-900">
          {song.artist?.stageName || song.artist?.user?.email || 'Sin artista'}
        </p>
      </td>
      <td className="py-4 px-4">
        <div className="flex items-center gap-1 text-sm text-gray-600">
          <ClockIcon className="h-4 w-4" />
          {formatDuration(song.duration)}
        </div>
      </td>
      <td className="py-4 px-4">
        <span
          className={`inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold ${statusInfo.badge}`}
        >
          {statusInfo.label}
        </span>
      </td>
      <td className="py-4 px-4">
        <div className="flex items-center gap-4 text-xs text-gray-600">
          <div className="flex items-center gap-1">
            <PlayIcon className="h-3 w-3" />
            {song.totalStreams.toLocaleString('es-ES')}
          </div>
          <div className="flex items-center gap-1">
            <HeartIcon className="h-3 w-3" />
            {song.totalLikes.toLocaleString('es-ES')}
          </div>
        </div>
      </td>
      <td className="py-4 px-4 text-right">
        <button
          onClick={() => onDelete(song)}
          className="inline-flex items-center rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-500 transition hover:border-red-300 hover:text-red-600 disabled:cursor-not-allowed disabled:opacity-60"
          disabled={isDeleting}
        >
          <TrashIcon className={`h-4 w-4 ${isDeleting ? 'animate-spin' : ''}`} />
          <span className="ml-1">Eliminar</span>
        </button>
      </td>
    </tr>
  );
}

export default function SongsPage() {
  const router = useRouter();
  const pathname = usePathname();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [uploadForm, setUploadForm] = useState(DEFAULT_UPLOAD_FORM);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const notificationShownRef = useRef(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const { data, isLoading, isFetching, refetch } = useSongs({ page, limit: PAGE_SIZE, enabled: true });
  const songs = data?.songs ?? [];

  const { data: artistsData } = useArtists({ page: 1, limit: 100, enabled: true });
  const artists = artistsData?.artists ?? [];

  const { mutateAsync: uploadSong } = useUploadSong();
  const { mutateAsync: deleteSong } = useDeleteSong();

  const navItems = [
    { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
    { name: 'Administrar usuarios', href: '/dashboard/users', icon: UsersIcon },
    { name: 'Gestionar canciones', href: '/dashboard/songs', icon: MusicalNoteIcon },
    { name: 'Artistas', href: '/dashboard/artists', icon: UsersIcon },
    { name: 'Administrar Playlists', href: '/dashboard/playlists', icon: ListBulletIcon },
    { name: 'Contenido destacado', href: '/dashboard/featured', icon: StarIcon },
    { name: 'Aprobar contenido', href: '/dashboard/approvals', icon: ShieldCheckIcon },
  ];

  const openUploadModal = () => {
    setUploadForm(DEFAULT_UPLOAD_FORM);
    setUploadProgress(0);
    setUploading(false);
    notificationShownRef.current = false;
    setShowUploadModal(true);
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      // Validar tipo de archivo
      const allowedTypes = ['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/x-wav', 'audio/m4a', 'audio/x-m4a', 'audio/flac', 'audio/x-flac'];
      if (!allowedTypes.includes(file.type)) {
        alert('Tipo de archivo no permitido. Solo se permiten: .mp3, .wav, .m4a, .flac');
        return;
      }
      setUploadForm((prev) => ({ ...prev, file }));
    }
  };

  const handleCoverFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      // Validar tipo de archivo
      const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];
      if (!allowedTypes.includes(file.type)) {
        alert('Tipo de archivo no permitido. Solo se permiten imágenes: .jpg, .jpeg, .png, .webp, .gif');
        return;
      }
      setUploadForm((prev) => ({ ...prev, coverFile: file }));
    }
  };

  const handleUploadSong = async (event: React.FormEvent) => {
    event.preventDefault();

    if (!uploadForm.file) {
      alert('Por favor selecciona un archivo');
      return;
    }

    if (!uploadForm.title.trim()) {
      alert('Por favor ingresa un título para la canción');
      return;
    }

    if (!uploadForm.artistId) {
      alert('Por favor selecciona un artista');
      return;
    }

    try {
      setUploading(true);
      setUploadProgress(0);
      notificationShownRef.current = false;
      
      // Subir archivos y crear registro en una sola petición transaccional
      await uploadSong({
        audioFile: uploadForm.file,
        coverFile: uploadForm.coverFile || undefined,
        songData: {
          title: uploadForm.title,
          artistId: uploadForm.artistId,
          status: 'published', // Estado publicado por defecto
        },
        onProgress: (progress) => {
          setUploadProgress(progress);
          // Cuando el progreso llegue al 100%, la subida está completa
          // Mostrar notificación solo una vez usando ref para evitar duplicados
          if (progress === 100 && !notificationShownRef.current) {
            notificationShownRef.current = true;
            // Pequeño delay para asegurar que el estado se actualice
            setTimeout(() => {
              toast.success('¡Canción subida exitosamente! Procesando metadatos...');
              setShowUploadModal(false);
              setUploadForm(DEFAULT_UPLOAD_FORM);
              setUploadProgress(0);
              notificationShownRef.current = false;
            }, 800);
          }
        },
      });
    } catch (error) {
      // Error manejado por los hooks
      setUploadProgress(0);
    } finally {
      setUploading(false);
    }
  };

  const handleDeleteSong = async (song: SongModel) => {
    const confirmed = window.confirm(`¿Seguro que deseas eliminar "${song.title}"?`);
    if (!confirmed) return;

    try {
      setDeletingId(song.id);
      await deleteSong(song.id);
    } finally {
      setDeletingId(null);
    }
  };

  const filteredSongs = useMemo(() => {
    if (!search.trim()) return songs;
    const query = search.toLowerCase();

    return songs.filter((song) => {
      return (
        song.title.toLowerCase().includes(query) ||
        song.artist?.stageName?.toLowerCase().includes(query) ||
        song.artist?.user?.email?.toLowerCase().includes(query)
      );
    });
  }, [songs, search]);

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

  return (
    <>
      <div className="min-h-screen bg-gray-100 flex">
        <aside className="hidden md:flex w-20 xl:w-64 flex-col bg-white border-r border-gray-200 py-6">
          <div className="flex flex-col items-center xl:items-start px-4 mb-8">
            <div className="h-10 w-10 rounded-xl bg-gradient-to-r from-purple-500 to-purple-600 flex items-center justify-center text-white font-bold">
              VM
            </div>
            <span className="mt-3 text-sm font-semibold text-gray-900 hidden xl:block">
              Vintage Admin
            </span>
          </div>

          <nav className="flex-1 flex flex-col space-y-1 px-2">
            {navItems.map((item) => {
              const isActive = pathname === item.href;

              return (
                <button
                  key={item.href}
                  onClick={() => {
                    if (!isActive) {
                      router.push(item.href);
                    }
                  }}
                  className={`flex items-center w-full gap-3 rounded-xl px-3 py-2 text-sm font-medium transition ${
                    isActive
                      ? 'bg-purple-100 text-purple-700'
                      : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
                  }`}
                >
                  <item.icon className="h-5 w-5" />
                  <span className="hidden xl:inline">{item.name}</span>
                </button>
              );
            })}
          </nav>
        </aside>

        <div className="flex-1 flex flex-col">
          <header className="bg-white border-b border-gray-200 shadow-sm">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
              <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                <div>
                  <h1 className="text-2xl font-bold text-gray-900">Gestionar canciones</h1>
                  <p className="mt-1 text-sm text-gray-500">
                    Consulta, filtra y gestiona las canciones del catálogo.
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
                    onClick={openUploadModal}
                    className="flex items-center gap-2 rounded-lg bg-purple-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-purple-700"
                  >
                    <PlusIcon className="h-4 w-4" />
                    Subir canción
                  </button>
                </div>
              </div>
            </div>
          </header>

          <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
            <div className="bg-white border border-gray-200 rounded-2xl shadow-sm p-6">
              <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                <div className="relative w-full sm:w-72">
                  <input
                    type="text"
                    value={search}
                    onChange={(event) => setSearch(event.target.value)}
                    placeholder="Buscar por título o artista..."
                    className="w-full rounded-full border border-gray-200 bg-gray-50 px-4 py-2 pl-10 text-sm text-gray-800 focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                  />
                  <MagnifyingGlassIcon className="h-5 w-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                </div>
                <p className="text-sm text-gray-500">{total.toLocaleString('es-ES')} canciones en total</p>
              </div>

              <div className="mt-6 overflow-hidden rounded-xl border border-gray-200">
                <table className="min-w-full divide-y divide-gray-200 bg-white">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Canción
                      </th>
                      <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Artista
                      </th>
                      <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Duración
                      </th>
                      <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Estado
                      </th>
                      <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Estadísticas
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
                          Cargando canciones...
                        </td>
                      </tr>
                    ) : filteredSongs.length === 0 ? (
                      <tr>
                        <td colSpan={6} className="py-12 text-center text-sm text-gray-500">
                          No se encontraron canciones.
                        </td>
                      </tr>
                    ) : (
                      filteredSongs.map((song: SongModel) => {
                        const statusInfo = statusLabels[song.status] ?? statusLabels.draft;
                        return (
                          <SongRow
                            key={song.id}
                            song={song}
                            statusInfo={statusInfo}
                            onDelete={handleDeleteSong}
                            isDeleting={deletingId === song.id}
                          />
                        );
                      })
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
          </main>
        </div>
      </div>

      {showUploadModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm px-4">
          <div className="w-full max-w-lg rounded-2xl bg-white shadow-xl">
            <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
              <div>
                <h2 className="text-lg font-semibold text-gray-900">Subir nueva canción</h2>
                <p className="text-sm text-gray-500">
                  Sube un archivo de audio y asigna un artista a la canción.
                </p>
              </div>
              <button
                onClick={() => {
                  if (!uploading) {
                    setShowUploadModal(false);
                    setUploadForm(DEFAULT_UPLOAD_FORM);
                    setUploadProgress(0);
                  }
                }}
                className="rounded-full p-1 text-gray-400 transition hover:bg-gray-100 hover:text-gray-600 disabled:cursor-not-allowed disabled:opacity-50"
                aria-label="Cerrar"
                disabled={uploading}
              >
                <XMarkIcon className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={handleUploadSong} className="px-6 py-6 space-y-4">
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Archivo de audio
                </label>
                <div className="mt-1">
                  {uploadForm.file ? (
                    <div className={`w-full border-2 rounded-lg p-4 transition ${
                      uploading 
                        ? 'border-purple-300 bg-purple-50' 
                        : 'border-green-300 bg-green-50 border-dashed'
                    }`}>
                      <div className="flex items-center gap-4">
                        <div className="flex-shrink-0 relative">
                          <div className={`h-16 w-16 rounded-lg flex items-center justify-center ${
                            uploading ? 'bg-purple-100 border-2 border-purple-400' : 'bg-green-100'
                          }`}>
                            {uploading ? (
                              <ArrowPathIcon className="h-8 w-8 text-purple-600 animate-spin" />
                            ) : (
                              <MusicalNoteIcon className="h-8 w-8 text-green-600" />
                            )}
                          </div>
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-2">
                            {uploading ? (
                              <ArrowPathIcon className="h-5 w-5 text-purple-600 flex-shrink-0 animate-spin" />
                            ) : (
                              <CheckCircleIcon className="h-5 w-5 text-green-600 flex-shrink-0" />
                            )}
                            <p className="text-sm font-semibold text-gray-900 truncate">
                              {uploadForm.file.name}
                            </p>
                          </div>
                          {uploading ? (
                            <>
                              <div className="mb-2">
                                <div className="flex items-center justify-between text-xs text-gray-600 mb-1">
                                  <span>Subiendo...</span>
                                  <span className="font-semibold text-purple-600">{uploadProgress}%</span>
                                </div>
                                <div className="w-full bg-gray-200 rounded-full h-2 overflow-hidden">
                                  <div
                                    className="bg-gradient-to-r from-purple-500 to-purple-600 h-full rounded-full transition-all duration-300 ease-out"
                                    style={{ width: `${uploadProgress}%` }}
                                  />
                                </div>
                              </div>
                              <p className="text-xs text-gray-600">
                                {(uploadForm.file.size / 1024 / 1024).toFixed(2)} MB • Subiendo...
                              </p>
                            </>
                          ) : (
                            <p className="text-xs text-gray-600">
                              {(uploadForm.file.size / 1024 / 1024).toFixed(2)} MB • Archivo seleccionado
                            </p>
                          )}
                        </div>
                        {!uploading && (
                          <button
                            type="button"
                            onClick={() => setUploadForm((prev) => ({ ...prev, file: null }))}
                            className="flex-shrink-0 rounded-lg p-2 text-gray-400 hover:bg-red-50 hover:text-red-600 transition"
                            disabled={uploading}
                            aria-label="Eliminar archivo"
                          >
                            <XMarkIcon className="h-5 w-5" />
                          </button>
                        )}
                      </div>
                    </div>
                  ) : (
                    <label className="flex flex-col items-center justify-center w-full h-32 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100 hover:border-purple-400 transition group">
                      <div className="flex flex-col items-center justify-center pt-5 pb-6">
                        <div className="h-12 w-12 rounded-lg bg-purple-100 flex items-center justify-center mb-3 group-hover:bg-purple-200 transition">
                          <DocumentArrowUpIcon className="h-6 w-6 text-purple-600" />
                        </div>
                        <p className="mb-2 text-sm text-gray-600 group-hover:text-gray-900">
                          <span className="font-semibold">Click para seleccionar</span> o arrastra el archivo
                        </p>
                        <p className="text-xs text-gray-500">MP3, WAV, M4A, FLAC (máx. 100MB)</p>
                      </div>
                      <input
                        type="file"
                        accept="audio/mpeg,audio/mp3,audio/wav,audio/x-wav,audio/m4a,audio/x-m4a,audio/flac,audio/x-flac"
                        onChange={handleFileChange}
                        className="hidden"
                        disabled={uploading}
                      />
                    </label>
                  )}
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Portada de la canción (opcional)
                </label>
                <div className="mt-1">
                  {uploadForm.coverFile ? (
                    <div className={`w-full border-2 rounded-lg p-4 transition ${
                      uploading 
                        ? 'border-purple-300 bg-purple-50' 
                        : 'border-blue-300 bg-blue-50'
                    }`}>
                      <div className="flex items-center gap-4">
                        <div className="flex-shrink-0 relative">
                          <div className={`h-20 w-20 rounded-lg overflow-hidden border-2 ${
                            uploading ? 'border-purple-400' : 'border-blue-300'
                          }`}>
                            {uploadForm.coverFile.type.startsWith('image/') ? (
                              <>
                                <img
                                  src={URL.createObjectURL(uploadForm.coverFile)}
                                  alt="Vista previa"
                                  className={`h-full w-full object-cover ${
                                    uploading ? 'opacity-50' : ''
                                  }`}
                                />
                                {uploading && (
                                  <div className="absolute inset-0 flex items-center justify-center bg-purple-500/20 backdrop-blur-sm">
                                    <ArrowPathIcon className="h-8 w-8 text-purple-600 animate-spin" />
                                  </div>
                                )}
                              </>
                            ) : (
                              <div className={`h-full w-full flex items-center justify-center ${
                                uploading ? 'bg-purple-100' : 'bg-blue-100'
                              }`}>
                                {uploading ? (
                                  <ArrowPathIcon className="h-8 w-8 text-purple-600 animate-spin" />
                                ) : (
                                  <PhotoIcon className="h-6 w-6 text-blue-600" />
                                )}
                              </div>
                            )}
                          </div>
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-2">
                            {uploading ? (
                              <ArrowPathIcon className="h-5 w-5 text-purple-600 flex-shrink-0 animate-spin" />
                            ) : (
                              <CheckCircleIcon className="h-5 w-5 text-blue-600 flex-shrink-0" />
                            )}
                            <p className="text-sm font-semibold text-gray-900 truncate">
                              {uploadForm.coverFile.name}
                            </p>
                          </div>
                          {uploading ? (
                            <>
                              <div className="mb-2">
                                <div className="flex items-center justify-between text-xs text-gray-600 mb-1">
                                  <span>Subiendo...</span>
                                  <span className="font-semibold text-purple-600">{uploadProgress}%</span>
                                </div>
                                <div className="w-full bg-gray-200 rounded-full h-2 overflow-hidden">
                                  <div
                                    className="bg-gradient-to-r from-purple-500 to-purple-600 h-full rounded-full transition-all duration-300 ease-out"
                                    style={{ width: `${uploadProgress}%` }}
                                  />
                                </div>
                              </div>
                              <p className="text-xs text-gray-600">
                                {(uploadForm.coverFile.size / 1024 / 1024).toFixed(2)} MB • Subiendo...
                              </p>
                            </>
                          ) : (
                            <p className="text-xs text-gray-600">
                              {(uploadForm.coverFile.size / 1024 / 1024).toFixed(2)} MB • Imagen seleccionada
                            </p>
                          )}
                        </div>
                        {!uploading && (
                          <button
                            type="button"
                            onClick={() => setUploadForm((prev) => ({ ...prev, coverFile: null }))}
                            className="flex-shrink-0 rounded-lg p-2 text-gray-400 hover:bg-red-50 hover:text-red-600 transition"
                            disabled={uploading}
                            aria-label="Eliminar imagen"
                          >
                            <XMarkIcon className="h-5 w-5" />
                          </button>
                        )}
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
                        disabled={uploading}
                      />
                    </label>
                  )}
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Título de la canción
                </label>
                <input
                  type="text"
                  value={uploadForm.title}
                  onChange={(event) =>
                    setUploadForm((prev) => ({ ...prev, title: event.target.value }))
                  }
                  required
                  disabled={uploading}
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100 disabled:bg-gray-50 disabled:cursor-not-allowed"
                  placeholder="Ej. Canción de ejemplo"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                  Artista
                </label>
                <select
                  value={uploadForm.artistId}
                  onChange={(event) =>
                    setUploadForm((prev) => ({ ...prev, artistId: event.target.value }))
                  }
                  required
                  disabled={uploading}
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100 disabled:bg-gray-50 disabled:cursor-not-allowed"
                >
                  <option value="">Selecciona un artista</option>
                  {artists.map((artist) => (
                    <option key={artist.id} value={artist.id}>
                      {artist.stageName || artist.user?.email || `Artista ${artist.id}`}
                    </option>
                  ))}
                </select>
                {artists.length === 0 && (
                  <p className="mt-1 text-xs text-gray-500">
                    No hay artistas disponibles. Crea un usuario con rol de artista primero.
                  </p>
                )}
              </div>

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => {
                    if (!uploading) {
                      setShowUploadModal(false);
                      setUploadForm(DEFAULT_UPLOAD_FORM);
                      setUploadProgress(0);
                    }
                  }}
                  className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-gray-300 hover:text-gray-700 disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={uploading}
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  disabled={uploading || !uploadForm.file || !uploadForm.title.trim() || !uploadForm.artistId}
                  className="inline-flex items-center rounded-lg bg-purple-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-purple-700 disabled:cursor-not-allowed disabled:bg-purple-400"
                >
                  {uploading ? (
                    <>
                      <ArrowPathIcon className="h-4 w-4 mr-2 animate-spin" />
                      Subiendo...
                    </>
                  ) : (
                    'Subir canción'
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}

