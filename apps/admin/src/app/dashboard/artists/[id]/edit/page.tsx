'use client';

import React, { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
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
      router.push('/dashboard/artists');
    } finally {
      setSaving(false);
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
        <button disabled={saving} className="px-4 py-2 rounded-md bg-purple-600 text-white">{saving ? 'Guardando...' : 'Guardar cambios'}</button>
      </form>
    </div>
  );
}


