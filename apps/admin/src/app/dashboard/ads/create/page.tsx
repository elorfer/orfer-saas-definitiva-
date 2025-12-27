'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'react-hot-toast';
import { useCreateAd, useUploadAdAudio, useUploadAdCover } from '@/hooks/useAds';

export default function CreateAdPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  // Formulario Simplificado (Global Mode)
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [advertiserName, setAdvertiserName] = useState('');
  const [clickThroughUrl, setClickThroughUrl] = useState('');
  const [durationSeconds, setDurationSeconds] = useState(15);
  // Targeting eliminado: Siempre es 'all'
  const [frequencyPerHour, setFrequencyPerHour] = useState(1);
  const [maxPlaysPerDay, setMaxPlaysPerDay] = useState<number | undefined>();
  // Priority eliminado: Siempre es 0 (Shuffle)
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

  // Hooks de datos eliminados (No necesitamos géneros ni artistas)

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

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      toast.error('Corrige los errores del formulario');
      return;
    }

    setLoading(true);
    try {
      // 1. Crear anuncio (sin archivos primero)
      const adData: any = {
        title,
        description: description || undefined,
        advertiserName,
        clickThroughUrl: clickThroughUrl || undefined,
        durationSeconds,
        fileSizeBytes: audioFile.size,
        targeting: 'all', // Hardcoded Global Mode
        targetGenres: undefined,
        targetArtists: undefined,
        frequencyPerHour,
        maxPlaysPerDay: maxPlaysPerDay || undefined,
        priority: 0, // Ignored by backend
        isSkippable,
        skipAfterSeconds,
        startDate: startDate || undefined,
        endDate: endDate || undefined,
        status: 'draft',
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
          <h1 className="text-2xl font-bold text-gray-900">Crear Anuncio de Audio (Global Mode 🌍)</h1>
          <p className="text-sm text-gray-500">Configuración simplificada. El anuncio se distribuirá aleatoriamente a todos los usuarios activos.</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm space-y-4">
            <h2 className="text-lg font-semibold text-gray-900">Información del Creativo</h2>

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
              <label className="block text-sm font-medium text-gray-700">Descripción interna</label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={2}
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
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">URL de redirección (Click-through)</label>
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
            <h2 className="text-lg font-semibold text-gray-900">Archivos Multimedia</h2>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Audio (MP3/AAC) <span className="text-red-500">*</span>
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
                <label className="block text-sm font-medium text-gray-700">Carátula (Imagen)</label>
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
                <p className="text-sm font-medium text-gray-700 mb-2">Vista previa:</p>
                <img src={coverPreview} alt="Preview" className="w-24 h-24 object-cover rounded-lg shadow-md" />
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Duración exacta (segundos) <span className="text-red-500">*</span>
              </label>
              <input
                type="number"
                min="5"
                max="60"
                value={durationSeconds}
                onChange={(e) => {
                  const val = parseInt(e.target.value) || 15;
                  setDurationSeconds(val);
                }}
                className="mt-1 w-32 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                required
              />
              <p className="mt-1 text-xs text-gray-500">Requerido para el contador del player.</p>
            </div>
          </div>

          <div className="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm space-y-4">
            <h2 className="text-lg font-semibold text-gray-900">Reglas de Entrega</h2>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Frecuencia Máxima (por hora)</label>
                <input
                  type="number"
                  min="1"
                  max="10"
                  value={frequencyPerHour}
                  onChange={(e) => setFrequencyPerHour(parseInt(e.target.value) || 1)}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
                <p className="mt-1 text-xs text-gray-500">Veces que un usuario oye este anuncio en 1h.</p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Límite Diario (Opcional)</label>
                <input
                  type="number"
                  min="1"
                  value={maxPlaysPerDay || ''}
                  onChange={(e) => setMaxPlaysPerDay(e.target.value ? parseInt(e.target.value) : undefined)}
                  placeholder="Ilimitado"
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>
            </div>

            <div className="flex items-center gap-4 mt-2">
              <label className="flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={isSkippable}
                  onChange={(e) => setIsSkippable(e.target.checked)}
                  className="mr-2 rounded text-brown-600 focus:ring-brown-500"
                />
                <span className="text-sm font-medium text-gray-700">Permitir saltar (Skip)</span>
              </label>
            </div>

            {isSkippable && (
              <div>
                <label className="block text-sm font-medium text-gray-700">Segundos antes del Skip</label>
                <input
                  type="number"
                  min="0"
                  max="30"
                  value={skipAfterSeconds}
                  onChange={(e) => setSkipAfterSeconds(parseInt(e.target.value) || 5)}
                  className="mt-1 w-32 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>
            )}
          </div>

          <div className="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm space-y-4">
            <h2 className="text-lg font-semibold text-gray-900">Vigencia de Campaña</h2>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Fecha de Inicio</label>
                <input
                  type="datetime-local"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Fecha de Fin</label>
                <input
                  type="datetime-local"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>
            </div>
          </div>

          <div className="flex gap-4 pt-4">
            <button
              type="button"
              onClick={() => router.back()}
              className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-gray-700 font-medium"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-6 py-2 bg-brown-600 text-white rounded-lg hover:bg-brown-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium shadow-sm"
            >
              {loading ? 'Creando...' : 'Publicar Anuncio Global'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}


