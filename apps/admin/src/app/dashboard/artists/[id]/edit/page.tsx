'use client';

import React, { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { CheckBadgeIcon, XMarkIcon } from '@heroicons/react/24/solid';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';

const countries: { code: string; name: string; flag: string }[] = [
  { code: 'AR', name: 'Argentina', flag: '🇦🇷' },
  { code: 'BR', name: 'Brasil', flag: '🇧🇷' },
  { code: 'CL', name: 'Chile', flag: '🇨🇱' },
  { code: 'CO', name: 'Colombia', flag: '🇨🇴' },
  { code: 'ES', name: 'España', flag: '🇪🇸' },
  { code: 'MX', name: 'México', flag: '🇲🇽' },
  { code: 'PE', name: 'Perú', flag: '🇵🇪' },
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
  const [profile, setProfile] = useState<File | null>(null);
  const [cover, setCover] = useState<File | null>(null);

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
      } finally {
        setLoading(false);
      }
    };
    run();
  }, [params.id]);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await apiClient.updateArtist(params.id, {
        name,
        nationalityCode: nationality,
        biography,
        featured,
        profileFile: profile,
        coverFile: cover,
      });
      toast.success('Artista actualizado exitosamente');
      router.push('/dashboard/artists');
    } catch (error: any) {
      toast.error(error?.response?.data?.message || 'Error al actualizar artista');
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
          <input className="mt-1 w-full border rounded-md px-3 py-2" value={name} onChange={e => setName(e.target.value)} required />
        </div>
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium">Nacionalidad</label>
            <select className="mt-1 w-full border rounded-md px-3 py-2" value={nationality} onChange={e => setNationality(e.target.value)}>
              <option value="">Seleccionar...</option>
              {countries.map(c => (
                <option key={c.code} value={c.code}>{c.flag} {c.name}</option>
              ))}
            </select>
          </div>
          <div className="flex items-end gap-2">
            <label className="text-sm font-medium">Destacado</label>
            <input type="checkbox" className="h-4 w-4" checked={featured} onChange={e => setFeatured(e.target.checked)} />
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
                disabled={verifying}
                className="px-4 py-2 text-sm rounded-md bg-red-100 text-red-700 hover:bg-red-200 disabled:opacity-50 disabled:cursor-not-allowed font-medium"
              >
                {verifying ? 'Removiendo...' : 'Quitar verificación'}
              </button>
            ) : (
              <button
                type="button"
                onClick={handleVerify}
                disabled={verifying}
                className="px-4 py-2 text-sm rounded-md bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium"
              >
                {verifying ? 'Verificando...' : 'Verificar Artista'}
              </button>
            )}
          </div>
        </div>
        
        <div>
          <label className="block text-sm font-medium">Biografía</label>
          <textarea className="mt-1 w-full border rounded-md px-3 py-2" rows={5} value={biography} onChange={e => setBiography(e.target.value)} />
        </div>
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium">Foto de perfil</label>
            <input type="file" accept="image/*" onChange={e => setProfile(e.target.files?.[0] || null)} />
          </div>
          <div>
            <label className="block text-sm font-medium">Portada</label>
            <input type="file" accept="image/*" onChange={e => setCover(e.target.files?.[0] || null)} />
          </div>
        </div>
        <button disabled={saving} className="px-4 py-2 rounded-md bg-brown-700 text-white">{saving ? 'Guardando...' : 'Guardar cambios'}</button>
      </form>
    </div>
  );
}


