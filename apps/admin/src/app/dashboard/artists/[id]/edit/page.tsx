'use client';

import React, { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { CheckBadgeIcon, XMarkIcon, ArrowPathIcon } from '@heroicons/react/24/solid';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';
import { useGenres } from '@/hooks/useGenres';
import { usePresignedUpload } from '@/hooks/usePresignedUpload';

const countries: { code: string; name: string; flag: string }[] = [
  { code: 'AR', name: 'Argentina', flag: '🇦🇷' },
  { code: 'BR', name: 'Brasil', flag: '🇧🇷' },
  { code: 'CL', name: 'Chile', flag: '🇨🇱' },
  { code: 'CO', name: 'Colombia', flag: '🇨🇴' },
  { code: 'CR', name: 'Costa Rica', flag: '🇨🇷' },
  { code: 'CU', name: 'Cuba', flag: '🇨🇺' },
  { code: 'DO', name: 'República Dominicana', flag: '🇩🇴' },
  { code: 'EC', name: 'Ecuador', flag: '🇪🇨' },
  { code: 'ES', name: 'España', flag: '🇪🇸' },
  { code: 'GT', name: 'Guatemala', flag: '🇬🇹' },
  { code: 'HN', name: 'Honduras', flag: '🇭🇳' },
  { code: 'MX', name: 'México', flag: '🇲🇽' },
  { code: 'NI', name: 'Nicaragua', flag: '🇳🇮' },
  { code: 'PA', name: 'Panamá', flag: '🇵🇦' },
  { code: 'PE', name: 'Perú', flag: '🇵🇪' },
  { code: 'PY', name: 'Paraguay', flag: '🇵🇾' },
  { code: 'UY', name: 'Uruguay', flag: '🇺🇾' },
  { code: 'VE', name: 'Venezuela', flag: '🇻🇪' },
];

export default function EditArtistPage() {
  const params = useParams() as { id: string };
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [name, setName] = useState('');
  const [nationality, setNationality] = useState<string>('');
  const [biography, setBiography] = useState('');
  const [featured, setFeatured] = useState(false);
  const [isVerified, setIsVerified] = useState(false);
  const [verifying, setVerifying] = useState(false);

  // Archivos e imágenes
  const [profileUrl, setProfileUrl] = useState<string | undefined>(undefined);
  const [coverUrl, setCoverUrl] = useState<string | undefined>(undefined);
  const [profileFile, setProfileFile] = useState<File | null>(null);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [profilePreview, setProfilePreview] = useState<string | null>(null);
  const [coverPreview, setCoverPreview] = useState<string | null>(null);

  const [selectedGenres, setSelectedGenres] = useState<string[]>([]);

  // Obtener géneros disponibles
  const { data: genresData, isLoading: genresLoading } = useGenres({ all: true, limit: 100 });
  const availableGenres = genresData?.genres || [];

  // Hook de subida directa a R2
  const { uploadFile: uploadToR2 } = usePresignedUpload({
    folder: 'images',
    onError: (err) => toast.error(`Error subiendo imagen: ${err.message}`),
  });

  useEffect(() => {
    const run = async () => {
      try {
        const res = await apiClient.getArtist(params.id);
        const a = res.data;
        setName(a.name ?? a.stageName ?? '');
        setNationality(a.nationalityCode ?? '');
        setBiography(a.biography ?? a.bio ?? '');
        setFeatured(!!a.featured || !!a.isFeatured);
        setIsVerified(!!a.isVerified || !!a.verificationStatus);

        // URLs iniciales
        setProfileUrl(a.profilePhotoUrl || a.profileUrl);
        setCoverUrl(a.coverPhotoUrl || a.coverUrl);

        // Cargar géneros del artista si existen
        if (a.genres && Array.isArray(a.genres)) {
          // Asegurarnos de tener solo nombres strings
          const genreNames = a.genres.map((g: any) => typeof g === 'string' ? g : g.name);
          setSelectedGenres(genreNames);
        } else {
          setSelectedGenres([]);
        }
      } finally {
        setLoading(false);
      }
    };
    run();
  }, [params.id]);

  const handleProfileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setProfileFile(file);
      setProfilePreview(URL.createObjectURL(file));
    }
  };

  const handleCoverChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setCoverFile(file);
      setCoverPreview(URL.createObjectURL(file));
    }
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      let finalProfileUrl = profileUrl;
      let finalCoverUrl = coverUrl;

      // 1. Subir Profile si cambió
      if (profileFile) {
        toast.loading('Subiendo perfil...', { id: 'artist-upload' });
        const res = await uploadToR2(profileFile);
        finalProfileUrl = res.publicUrl;
      }

      // 2. Subir Cover si cambió
      if (coverFile) {
        toast.loading('Subiendo portada...', { id: 'artist-upload' });
        const res = await uploadToR2(coverFile);
        finalCoverUrl = res.publicUrl;
      }

      // 3. Actualizar Artista
      toast.loading('Guardando cambios...', { id: 'artist-upload' });
      await apiClient.updateArtist(params.id, {
        name,
        nationalityCode: nationality,
        biography,
        featured,
        genres: selectedGenres,
        profileUrl: finalProfileUrl, // Pasamos URL
        coverUrl: finalCoverUrl,     // Pasamos URL
      });

      toast.success('Artista actualizado exitosamente', { id: 'artist-upload' });
      router.push('/dashboard/artists');
    } catch (error: any) {
      const msg = error?.response?.data?.message || error.message || 'Error al actualizar artista';
      toast.error(msg, { id: 'artist-upload' });
    } finally {
      setSaving(false);
    }
  };

  const handleVerify = async () => {
    setVerifying(true);
    try {
      await apiClient.verifyArtist(params.id);
      setIsVerified(true);
      toast.success('Artista verificado exitosamente');
      // Refrescar datos del artista
      const res = await apiClient.getArtist(params.id);
      const a = res.data;
      setIsVerified(!!a.isVerified || !!a.verificationStatus);
    } catch (error: any) {
      toast.error(error?.response?.data?.message || 'Error al verificar artista');
    } finally {
      setVerifying(false);
    }
  };

  const handleUnverify = async () => {
    setVerifying(true);
    try {
      await apiClient.unverifyArtist(params.id);
      setIsVerified(false);
      toast.success('Verificación removida exitosamente');
      // Refrescar datos del artista
      const res = await apiClient.getArtist(params.id);
      const a = res.data;
      setIsVerified(!!a.isVerified || !!a.verificationStatus);
    } catch (error: any) {
      toast.error(error?.response?.data?.message || 'Error al remover verificación');
    } finally {
      setVerifying(false);
    }
  };

  if (loading) return <div className="p-6">Cargando...</div>;

  return (
    <div className="p-6 max-w-3xl">
      <h1 className="text-2xl font-bold mb-4">Editar Artista</h1>
      <form onSubmit={handleSave} className="space-y-4">
        <div>
          <label className="block text-sm font-medium">Nombre</label>
          <input className="mt-1 w-full border rounded-md px-3 py-2" value={name} onChange={e => setName(e.target.value)} required disabled={saving} />
        </div>
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium">Nacionalidad</label>
            <select className="mt-1 w-full border rounded-md px-3 py-2" value={nationality} onChange={e => setNationality(e.target.value)} disabled={saving}>
              <option value="">Seleccionar...</option>
              {countries.map(c => (
                <option key={c.code} value={c.code}>{c.flag} {c.name}</option>
              ))}
            </select>
          </div>
          <div className="flex items-end gap-2">
            <label className="text-sm font-medium">Destacado</label>
            <input type="checkbox" className="h-4 w-4" checked={featured} onChange={e => setFeatured(e.target.checked)} disabled={saving} />
          </div>
        </div>

        {/* Sección de Verificación */}
        <div className="p-4 bg-gray-50 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Estado de Verificación
                </label>
                {isVerified ? (
                  <div className="flex items-center gap-2 text-blue-600">
                    <CheckBadgeIcon className="h-5 w-5" />
                    <span className="text-sm font-medium">Verificado</span>
                  </div>
                ) : (
                  <span className="text-sm text-gray-500">No verificado</span>
                )}
              </div>
            </div>
            {isVerified ? (
              <button
                type="button"
                onClick={handleUnverify}
                disabled={verifying || saving}
                className="px-4 py-2 text-sm rounded-md bg-red-100 text-red-700 hover:bg-red-200 disabled:opacity-50 disabled:cursor-not-allowed font-medium"
              >
                {verifying ? 'Removiendo...' : 'Quitar verificación'}
              </button>
            ) : (
              <button
                type="button"
                onClick={handleVerify}
                disabled={verifying || saving}
                className="px-4 py-2 text-sm rounded-md bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium"
              >
                {verifying ? 'Verificando...' : 'Verificar Artista'}
              </button>
            )}
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium">Géneros</label>
          {genresLoading ? (
            <div className="mt-1 text-sm text-gray-500">Cargando géneros...</div>
          ) : (
            <div className="mt-1 space-y-2">
              <div className="flex flex-wrap gap-2">
                {availableGenres.map((genre) => (
                  <label
                    key={genre.id}
                    className={`inline-flex items-center px-3 py-1.5 rounded-lg border text-sm cursor-pointer transition ${selectedGenres.includes(genre.name)
                        ? 'bg-brown-100 border-brown-500 text-brown-700'
                        : 'bg-white border-gray-200 text-gray-700 hover:border-brown-300'
                      }`}
                  >
                    <input
                      type="checkbox"
                      className="sr-only"
                      checked={selectedGenres.includes(genre.name)}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedGenres([...selectedGenres, genre.name]);
                        } else {
                          setSelectedGenres(selectedGenres.filter((g) => g !== genre.name));
                        }
                      }}
                      disabled={saving}
                    />
                    <span>{genre.name}</span>
                  </label>
                ))}
              </div>
              {selectedGenres.length === 0 && (
                <p className="text-xs text-gray-500">No hay géneros seleccionados.</p>
              )}
            </div>
          )}
        </div>

        <div>
          <label className="block text-sm font-medium">Biografía</label>
          <textarea className="mt-1 w-full border rounded-md px-3 py-2" rows={5} value={biography} onChange={e => setBiography(e.target.value)} disabled={saving} />
        </div>

        <div className="grid md:grid-cols-2 gap-6">
          <div className="bg-white border border-gray-200 rounded-2xl p-4 shadow-sm">
            <label className="block text-sm font-medium mb-2">Foto de perfil</label>
            <div className="aspect-square rounded-xl bg-gray-50 border border-dashed border-gray-300 flex items-center justify-center overflow-hidden mb-3">
              {profilePreview ? (
                <img src={profilePreview} alt="preview" className="h-full w-full object-cover" />
              ) : profileUrl ? (
                <img src={profileUrl} alt="current" className="h-full w-full object-cover" />
              ) : (
                <span className="text-gray-400 text-sm">Sin imagen</span>
              )}
            </div>
            <input type="file" accept="image/*" onChange={handleProfileChange} disabled={saving} className="text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-brown-50 file:text-brown-700 hover:file:bg-brown-100 cursor-pointer w-full" />
          </div>

          <div className="bg-white border border-gray-200 rounded-2xl p-4 shadow-sm">
            <label className="block text-sm font-medium mb-2">Portada</label>
            <div className="aspect-[16/9] rounded-xl bg-gray-50 border border-dashed border-gray-300 flex items-center justify-center overflow-hidden mb-3">
              {coverPreview ? (
                <img src={coverPreview} alt="preview" className="h-full w-full object-cover" />
              ) : coverUrl ? (
                <img src={coverUrl} alt="current" className="h-full w-full object-cover" />
              ) : (
                <span className="text-gray-400 text-sm">Sin imagen</span>
              )}
            </div>
            <input type="file" accept="image/*" onChange={handleCoverChange} disabled={saving} className="text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-brown-50 file:text-brown-700 hover:file:bg-brown-100 cursor-pointer w-full" />
          </div>
        </div>

        <button disabled={saving} className="flex items-center gap-2 px-6 py-2 rounded-lg bg-brown-700 text-white font-medium hover:bg-brown-800 disabled:opacity-50">
          {saving ? (
            <>
              <ArrowPathIcon className="h-4 w-4 animate-spin" />
              Guardando...
            </>
          ) : 'Guardar cambios'}
        </button>
      </form>
    </div>
  );
}
