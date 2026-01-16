'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'react-hot-toast';
import { useCreateAd } from '@/hooks/useAds';
import { usePresignedUpload } from '@/hooks/usePresignedUpload';
import { ArrowPathIcon, CloudArrowUpIcon, MusicalNoteIcon, PhotoIcon } from '@heroicons/react/24/outline';

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

  // Estados de subida
  const [uploadProgress, setUploadProgress] = useState(0);

  // Archivos
  const [audioFile, setAudioFile] = useState<File | null>(null);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [audioPreview, setAudioPreview] = useState<string | null>(null);
  const [coverPreview, setCoverPreview] = useState<string | null>(null);

  const createAd = useCreateAd();

  // Hooks de subida directa a R2
  const { uploadFile: uploadAudio } = usePresignedUpload({
    folder: 'audio',
    onError: (err) => toast.error(`Error subiendo audio: ${err.message}`),
  });

  const { uploadFile: uploadCover } = usePresignedUpload({
    folder: 'images',
    onError: (err) => toast.error(`Error subiendo portada: ${err.message}`),
  });

  const handleAudioChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validar tipo
    const allowedTypes = ['audio/mpeg', 'audio/mp3', 'audio/aac', 'audio/ogg', 'audio/wav'];
    if (!allowedTypes.includes(file.type)) {
      toast.error('Tipo de archivo no permitido. Use MP3, AAC, OGG o WAV');
      return;
    }

    // Validar tamaño (15MB para anuncios debería ser suficiente)
    if (file.size > 15 * 1024 * 1024) {
      toast.error('El archivo es demasiado grande. Máximo 15MB');
      return;
    }

    setAudioFile(file);

    // Crear preview
    const reader = new FileReader();
    reader.onload = (e) => {
      setAudioPreview(e.target?.result as string);
    };
    reader.readAsDataURL(file);

    // Intentar leer duración (básico)
    const audio = new Audio();
    audio.src = URL.createObjectURL(file);
    audio.onloadedmetadata = () => {
      if (audio.duration && audio.duration > 0 && audio.duration < 120) {
        setDurationSeconds(Math.ceil(audio.duration));
      }
    };
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
    setUploadProgress(0);

    try {
      let audioUrl = '';
      let coverImageUrl = undefined;

      // 1. Subir Audio a R2
      if (audioFile) {
        toast.loading('Subiendo audio...', { id: 'ad-upload' });
        const audioResult = await uploadAudio(audioFile);
        audioUrl = audioResult.publicUrl;
        setUploadProgress(50);
      }

      // 2. Subir Cover a R2 (si existe)
      if (coverFile) {
        toast.loading('Subiendo portada...', { id: 'ad-upload' });
        const coverResult = await uploadCover(coverFile);
        coverImageUrl = coverResult.publicUrl;
        setUploadProgress(80);
      }

      // 3. Crear Anuncio con las URLs
      toast.loading('Guardando anuncio...', { id: 'ad-upload' });

      const adData: any = {
        title,
        description: description || undefined,
        advertiserName,
        clickThroughUrl: clickThroughUrl || undefined,
        durationSeconds,
        fileSizeBytes: audioFile!.size,
        audioUrl, // enviamos URL directa
        coverImageUrl, // enviamos URL directa
        targeting: 'all',
        frequencyPerHour,
        maxPlaysPerDay: maxPlaysPerDay || undefined,
        priority: 0,
        isSkippable,
        skipAfterSeconds,
        startDate: startDate || undefined,
        endDate: endDate || undefined,
        status: 'active', // Lo creamos activo por defecto si se sube todo bien
      };

      await createAd.mutateAsync(adData);

      toast.success('Anuncio creado exitosamente', { id: 'ad-upload' });
      router.push('/dashboard/ads');
    } catch (error: any) {
      console.error(error);
      const msg = error?.response?.data?.message || error?.message || 'Error al crear anuncio';
      toast.error(typeof msg === 'string' ? msg : JSON.stringify(msg), { id: 'ad-upload' });
    } finally {
      setLoading(false);
      setUploadProgress(0);
    }
  };

  return (
    <div className="p-6">
      <div className="max-w-4xl mx-auto">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Crear Anuncio de Audio (Global Mode 🌍)</h1>
          <p className="text-sm text-gray-500">Configuración simplificada. Sube tus archivos directamente a la nube.</p>
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
                disabled={loading}
              />
              {errors.title && <p className="mt-1 text-xs text-red-600">{errors.title}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">Descripción interna</label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={2}
                disabled={loading}
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
                disabled={loading}
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
                disabled={loading}
                className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
              />
            </div>
          </div>

          <div className="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm space-y-4">
            <h2 className="text-lg font-semibold text-gray-900">Archivos Multimedia</h2>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Audio Upload */}
              <div className={`border-2 border-dashed rounded-lg p-4 transition ${loading ? 'bg-gray-50' : 'hover:border-brown-500'}`}>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Audio (MP3/AAC/OGG) <span className="text-red-500">*</span>
                </label>
                <div className="flex flex-col items-center justify-center text-center gap-2">
                  {audioPreview ? (
                    <div className="w-full bg-gray-100 rounded p-2 mb-2">
                      <MusicalNoteIcon className="h-8 w-8 mx-auto text-brown-600 mb-1" />
                      <p className="text-xs text-gray-600 truncate max-w-[200px]">{audioFile?.name}</p>
                      <audio src={audioPreview} controls className="w-full mt-2 h-8" />
                    </div>
                  ) : (
                    <div className="h-20 w-full flex items-center justify-center bg-gray-50 rounded text-gray-400">
                      <MusicalNoteIcon className="h-8 w-8" />
                    </div>
                  )}

                  {!loading && (
                    <input
                      type="file"
                      accept="audio/mpeg,audio/mp3,audio/aac,audio/ogg,audio/wav"
                      onChange={handleAudioChange}
                      className="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-brown-50 file:text-brown-700 hover:file:bg-brown-100 cursor-pointer"
                    />
                  )}
                </div>
                {errors.audioFile && <p className="mt-1 text-xs text-red-600">{errors.audioFile}</p>}
              </div>

              {/* Cover Upload */}
              <div className={`border-2 border-dashed rounded-lg p-4 transition ${loading ? 'bg-gray-50' : 'hover:border-brown-500'}`}>
                <label className="block text-sm font-medium text-gray-700 mb-2">Carátula (Imagen)</label>
                <div className="flex flex-col items-center justify-center text-center gap-2">
                  {coverPreview ? (
                    <img src={coverPreview} alt="Preview" className="h-32 w-32 object-cover rounded-lg shadow-sm mb-2" />
                  ) : (
                    <div className="h-32 w-32 flex items-center justify-center bg-gray-50 rounded-lg text-gray-400 border border-gray-100 mb-2">
                      <PhotoIcon className="h-10 w-10" />
                    </div>
                  )}

                  {!loading && (
                    <input
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      onChange={handleCoverChange}
                      className="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-brown-50 file:text-brown-700 hover:file:bg-brown-100 cursor-pointer"
                    />
                  )}
                </div>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Duración exacta (segundos) <span className="text-red-500">*</span>
              </label>
              <div className="flex items-center gap-2">
                <input
                  type="number"
                  min="5"
                  max="60"
                  value={durationSeconds}
                  onChange={(e) => {
                    const val = parseInt(e.target.value) || 15;
                    setDurationSeconds(val);
                  }}
                  disabled={loading}
                  className="mt-1 w-32 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                  required
                />
                <span className="text-xs text-gray-500 mt-1">Requerido. Se intenta autodetectar.</span>
              </div>
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
                  disabled={loading}
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
                  disabled={loading}
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
                  disabled={loading}
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
                  disabled={loading}
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
                  disabled={loading}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Fecha de Fin</label>
                <input
                  type="datetime-local"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  disabled={loading}
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                />
              </div>
            </div>
          </div>

          <div className="flex gap-4 pt-4">
            <button
              type="button"
              onClick={() => router.back()}
              disabled={loading}
              className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-gray-700 font-medium disabled:opacity-50"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-6 py-2 bg-brown-600 text-white rounded-lg hover:bg-brown-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium shadow-sm flex items-center gap-2"
            >
              {loading ? (
                <>
                  <CloudArrowUpIcon className="h-5 w-5 animate-bounce" />
                  Subiendo {uploadProgress}%
                </>
              ) : 'Publicar Anuncio Global'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
