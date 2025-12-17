'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'react-hot-toast';
import { useCreateAd, useUploadAdAudio, useUploadAdCover } from '@/hooks/useAds';
import { useGenres } from '@/hooks/useGenres';
import { useAllArtists } from '@/hooks/useArtists';

export default function CreateAdPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  
  // Formulario
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [advertiserName, setAdvertiserName] = useState('');
  const [clickThroughUrl, setClickThroughUrl] = useState('');
  const [durationSeconds, setDurationSeconds] = useState(15);
  const [targeting, setTargeting] = useState<'all' | 'genre' | 'artist' | 'playlist'>('all');
  const [targetGenres, setTargetGenres] = useState<string[]>([]);
  const [targetArtists, setTargetArtists] = useState<string[]>([]);
  const [frequencyPerHour, setFrequencyPerHour] = useState(1);
  const [maxPlaysPerDay, setMaxPlaysPerDay] = useState<number | undefined>();
  const [priority, setPriority] = useState(0);
  const [isSkippable, setIsSkippable] = useState(true);
  const [skipAfterSeconds, setSkipAfterSeconds] = useState(5);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  
  // Archivos
  const [audioFile, setAudioFile] = useState<File | null>(null);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [audioPreview, setAudioPreview] = useState<string | null>(null);
  const [coverPreview, setCoverPreview] = useState<string | null>(null);

  const createAd = useCreateAd();
  const uploadAudio = useUploadAdAudio();
  const uploadCover = useUploadAdCover();
  
  const { data: genresData } = useGenres({ all: true, limit: 100 });
  const { data: artistsData } = useAllArtists();
  const availableGenres = genresData?.genres || [];
  const availableArtists = artistsData?.artists || [];

  const handleAudioChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validar tipo
    const allowedTypes = ['audio/mpeg', 'audio/mp3', 'audio/aac', 'audio/ogg'];
    if (!allowedTypes.includes(file.type)) {
      toast.error('Tipo de archivo no permitido. Use MP3, AAC u OGG');
      return;
    }

    // Validar tamaño (5MB)
    if (file.size > 5 * 1024 * 1024) {
      toast.error('El archivo es demasiado grande. Máximo 5MB');
      return;
    }

    setAudioFile(file);
    
    // Crear preview
    const reader = new FileReader();
    reader.onload = (e) => {
      setAudioPreview(e.target?.result as string);
    };
    reader.readAsDataURL(file);
  };

  const handleCoverChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validar tipo
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
      toast.error('Tipo de archivo no permitido. Use JPG, PNG o WebP');
      return;
    }

    // Validar tamaño (2MB)
    if (file.size > 2 * 1024 * 1024) {
      toast.error('El archivo es demasiado grande. Máximo 2MB');
      return;
    }

    setCoverFile(file);
    
    // Crear preview
    const reader = new FileReader();
    reader.onload = (e) => {
      setCoverPreview(e.target?.result as string);
    };
    reader.readAsDataURL(file);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Validaciones
    const newErrors: Record<string, string> = {};
    if (!title.trim()) newErrors.title = 'El título es requerido';
    if (!advertiserName.trim()) newErrors.advertiserName = 'El nombre del anunciante es requerido';
    if (!audioFile) newErrors.audioFile = 'El archivo de audio es requerido';
    if (durationSeconds < 5 || durationSeconds > 60) {
      newErrors.durationSeconds = 'La duración debe estar entre 5 y 60 segundos';
    }
    if (targeting === 'genre' && targetGenres.length === 0) {
      newErrors.targetGenres = 'Debe seleccionar al menos un género';
    }
    if (targeting === 'artist' && targetArtists.length === 0) {
      newErrors.targetArtists = 'Debe seleccionar al menos un artista';
    }

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      toast.error('Corrige los errores del formulario');
      return;
    }

    setLoading(true);
    try {
      // 1. Crear anuncio (sin archivos primero)
      // audioUrl y coverImageUrl se actualizarán después de subir archivos
      const adData: any = {
        title,
        description: description || undefined,
        advertiserName,
        clickThroughUrl: clickThroughUrl || undefined,
        durationSeconds,
        fileSizeBytes: audioFile.size,
        targeting,
        targetGenres: targeting === 'genre' ? targetGenres : undefined,
        targetArtists: targeting === 'artist' ? targetArtists : undefined,
        frequencyPerHour,
        maxPlaysPerDay: maxPlaysPerDay || undefined,
        priority,
        isSkippable,
        skipAfterSeconds,
        startDate: startDate || undefined,
        endDate: endDate || undefined,
        status: 'draft', // Crear como borrador inicialmente
        // audioUrl se agregará después de subir el archivo
      };

      const createdAd = await createAd.mutateAsync(adData);
      const adId = createdAd.id;

      // 2. Subir archivos si existen
      if (audioFile) {
        await uploadAudio.mutateAsync({ id: adId, file: audioFile });
      }
      if (coverFile) {
        await uploadCover.mutateAsync({ id: adId, file: coverFile });
      }

      toast.success('Anuncio creado exitosamente');
      router.push('/dashboard/ads');
    } catch (error: any) {
      const msg = error?.response?.data?.message || error?.message || 'Error al crear anuncio';
      toast.error(typeof msg === 'string' ? msg : JSON.stringify(msg));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="p-6">
      <div className="max-w-4xl mx-auto">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Crear Anuncio de Audio</h1>
          <p className="text-sm text-gray-500">Completa la información y sube los archivos de audio e imagen.</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm space-y-4">
            <h2 className="text-lg font-semibold text-gray-900">Información Básica</h2>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">
                Título del anuncio <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => {
                  setTitle(e.target.value);
                  setErrors((prev) => ({ ...prev, title: '' }));
                }}
                className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                required
              />
              {errors.title && <p className="mt-1 text-xs text-red-600">{errors.title}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">Descripción</label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={3}
                className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Nombre del anunciante <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                value={advertiserName}
                onChange={(e) => {
                  setAdvertiserName(e.target.value);
                  setErrors((prev) => ({ ...prev, advertiserName: '' }));
                }}
                className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                required
              />
              {errors.advertiserName && <p className="mt-1 text-xs text-red-600">{errors.advertiserName}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">URL de click-through (opcional)</label>
              <input
                type="url"
                value={clickThroughUrl}
                onChange={(e) => setClickThroughUrl(e.target.value)}
                placeholder="https://ejemplo.com"
                className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
              />
            </div>
          </div>

          <div className="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm space-y-4">
            <h2 className="text-lg font-semibold text-gray-900">Archivos</h2>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Archivo de audio <span className="text-red-500">*</span>
                </label>
                <input
                  type="file"
                  accept="audio/mpeg,audio/mp3,audio/aac,audio/ogg"
                  onChange={handleAudioChange}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                  required
                />
                {errors.audioFile && <p className="mt-1 text-xs text-red-600">{errors.audioFile}</p>}
                {audioFile && (
                  <p className="mt-1 text-xs text-gray-500">
                    {audioFile.name} ({(audioFile.size / 1024 / 1024).toFixed(2)} MB)
                  </p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Carátula (opcional)</label>
                <input
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  onChange={handleCoverChange}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
                {coverFile && (
                  <p className="mt-1 text-xs text-gray-500">
                    {coverFile.name} ({(coverFile.size / 1024 / 1024).toFixed(2)} MB)
                  </p>
                )}
              </div>
            </div>

            {coverPreview && (
              <div className="mt-4">
                <p className="text-sm font-medium text-gray-700 mb-2">Vista previa de carátula:</p>
                <img src={coverPreview} alt="Preview" className="w-32 h-32 object-cover rounded-lg" />
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Duración (segundos) <span className="text-red-500">*</span>
              </label>
              <input
                type="number"
                min="5"
                max="60"
                value={durationSeconds}
                onChange={(e) => {
                  const val = parseInt(e.target.value) || 15;
                  setDurationSeconds(val);
                  setErrors((prev) => ({ ...prev, durationSeconds: '' }));
                }}
                className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                required
              />
              {errors.durationSeconds && <p className="mt-1 text-xs text-red-600">{errors.durationSeconds}</p>}
              <p className="mt-1 text-xs text-gray-500">Entre 5 y 60 segundos</p>
            </div>
          </div>

          <div className="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm space-y-4">
            <h2 className="text-lg font-semibold text-gray-900">Targeting</h2>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Tipo de targeting</label>
              <select
                value={targeting}
                onChange={(e) => {
                  setTargeting(e.target.value as any);
                  setTargetGenres([]);
                  setTargetArtists([]);
                }}
                className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
              >
                <option value="all">Todos los usuarios</option>
                <option value="genre">Por género</option>
                <option value="artist">Por artista</option>
                <option value="playlist">Por playlist</option>
              </select>
            </div>

            {targeting === 'genre' && (
              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Géneros objetivo <span className="text-red-500">*</span>
                </label>
                <div className="mt-1 flex flex-wrap gap-2">
                  {availableGenres.map((genre) => (
                    <label
                      key={genre.id}
                      className={`inline-flex items-center px-3 py-1.5 rounded-lg border text-sm cursor-pointer transition ${
                        targetGenres.includes(genre.name)
                          ? 'bg-brown-100 border-brown-500 text-brown-700'
                          : 'bg-white border-gray-200 text-gray-700 hover:border-brown-300'
                      }`}
                    >
                      <input
                        type="checkbox"
                        className="sr-only"
                        checked={targetGenres.includes(genre.name)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setTargetGenres([...targetGenres, genre.name]);
                          } else {
                            setTargetGenres(targetGenres.filter((g) => g !== genre.name));
                          }
                          setErrors((prev) => ({ ...prev, targetGenres: '' }));
                        }}
                      />
                      {genre.name}
                    </label>
                  ))}
                </div>
                {errors.targetGenres && <p className="mt-1 text-xs text-red-600">{errors.targetGenres}</p>}
              </div>
            )}

            {targeting === 'artist' && (
              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Artistas objetivo <span className="text-red-500">*</span>
                </label>
                <div className="mt-1 max-h-40 overflow-y-auto border border-gray-200 rounded-lg p-2">
                  {availableArtists.map((artist) => (
                    <label
                      key={artist.id}
                      className={`flex items-center px-3 py-2 rounded-lg cursor-pointer transition ${
                        targetArtists.includes(artist.id)
                          ? 'bg-brown-100 text-brown-700'
                          : 'hover:bg-gray-50'
                      }`}
                    >
                      <input
                        type="checkbox"
                        className="mr-2"
                        checked={targetArtists.includes(artist.id)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setTargetArtists([...targetArtists, artist.id]);
                          } else {
                            setTargetArtists(targetArtists.filter((id) => id !== artist.id));
                          }
                          setErrors((prev) => ({ ...prev, targetArtists: '' }));
                        }}
                      />
                      {artist.stageName || artist.name || 'Sin nombre'}
                    </label>
                  ))}
                </div>
                {errors.targetArtists && <p className="mt-1 text-xs text-red-600">{errors.targetArtists}</p>}
              </div>
            )}
          </div>

          <div className="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm space-y-4">
            <h2 className="text-lg font-semibold text-gray-900">Configuración de Reproducción</h2>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Frecuencia por hora</label>
                <input
                  type="number"
                  min="1"
                  max="10"
                  value={frequencyPerHour}
                  onChange={(e) => setFrequencyPerHour(parseInt(e.target.value) || 1)}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Máximo de reproducciones por día</label>
                <input
                  type="number"
                  min="1"
                  value={maxPlaysPerDay || ''}
                  onChange={(e) => setMaxPlaysPerDay(e.target.value ? parseInt(e.target.value) : undefined)}
                  placeholder="Sin límite"
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Prioridad (0-100)</label>
                <input
                  type="number"
                  min="0"
                  max="100"
                  value={priority}
                  onChange={(e) => setPriority(parseInt(e.target.value) || 0)}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>
            </div>

            <div className="flex items-center gap-4">
              <label className="flex items-center">
                <input
                  type="checkbox"
                  checked={isSkippable}
                  onChange={(e) => setIsSkippable(e.target.checked)}
                  className="mr-2"
                />
                <span className="text-sm font-medium text-gray-700">Permitir saltar anuncio</span>
              </label>
            </div>

            {isSkippable && (
              <div>
                <label className="block text-sm font-medium text-gray-700">Segundos antes de permitir skip</label>
                <input
                  type="number"
                  min="0"
                  max="30"
                  value={skipAfterSeconds}
                  onChange={(e) => setSkipAfterSeconds(parseInt(e.target.value) || 5)}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>
            )}
          </div>

          <div className="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm space-y-4">
            <h2 className="text-lg font-semibold text-gray-900">Programación (Opcional)</h2>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Fecha de inicio</label>
                <input
                  type="datetime-local"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Fecha de fin</label>
                <input
                  type="datetime-local"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>
            </div>
          </div>

          <div className="flex gap-4">
            <button
              type="button"
              onClick={() => router.back()}
              className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-6 py-2 bg-brown-600 text-white rounded-lg hover:bg-brown-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? 'Creando...' : 'Crear Anuncio'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}


